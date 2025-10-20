/*
 * Export utilities for webhook requests in various formats.
 */

using GLib;
using Json;

namespace Sonar {

    /**
     * Export format enumeration.
     */
    public enum ExportFormat {
        HAR,    // HTTP Archive format
        CSV,    // Comma-Separated Values
        CURL,   // cURL command
        JSON    // JSON format
    }

    /**
     * Utility class for exporting webhook requests in various formats.
     */
    public class ExportUtils : GLib.Object {

        /**
         * Export a single request to the specified format.
         *
         * @param request The request to export
         * @param format The desired export format
         * @return Exported data as string
         */
        public static string export_request(WebhookRequest request, ExportFormat format) throws GLib.Error {
            switch (format) {
                case ExportFormat.HAR:
                    return export_to_har(new Gee.ArrayList<WebhookRequest>.wrap({request}));
                case ExportFormat.CSV:
                    return export_to_csv(new Gee.ArrayList<WebhookRequest>.wrap({request}), true);
                case ExportFormat.CURL:
                    return export_to_curl(request);
                case ExportFormat.JSON:
                    return export_to_json(new Gee.ArrayList<WebhookRequest>.wrap({request}));
                default:
                    throw new IOError.INVALID_ARGUMENT("Unknown export format");
            }
        }

        /**
         * Export multiple requests to the specified format.
         *
         * @param requests List of requests to export
         * @param format The desired export format
         * @return Exported data as string
         */
        public static string export_requests(Gee.ArrayList<WebhookRequest> requests, ExportFormat format) throws GLib.Error {
            switch (format) {
                case ExportFormat.HAR:
                    return export_to_har(requests);
                case ExportFormat.CSV:
                    return export_to_csv(requests, true);
                case ExportFormat.CURL:
                    // For multiple requests, export as separate cURL commands
                    var builder = new StringBuilder();
                    foreach (var request in requests) {
                        if (builder.len > 0) {
                            builder.append("\n\n");
                        }
                        builder.append(export_to_curl(request));
                    }
                    return builder.str;
                case ExportFormat.JSON:
                    return export_to_json(requests);
                default:
                    throw new IOError.INVALID_ARGUMENT("Unknown export format");
            }
        }

        /**
         * Export requests to HAR (HTTP Archive) format.
         * HAR is the industry standard for HTTP traffic recording.
         *
         * @param requests List of requests to export
         * @return HAR formatted JSON string
         */
        public static string export_to_har(Gee.ArrayList<WebhookRequest> requests) {
            var builder = new Json.Builder();
            builder.begin_object();

            // HAR root object
            builder.set_member_name("log");
            builder.begin_object();

            // HAR version
            builder.set_member_name("version");
            builder.add_string_value("1.2");

            // Creator
            builder.set_member_name("creator");
            builder.begin_object();
            builder.set_member_name("name");
            builder.add_string_value("Sonar");
            builder.set_member_name("version");
            builder.add_string_value(Config.VERSION);
            builder.end_object();

            // Entries
            builder.set_member_name("entries");
            builder.begin_array();

            foreach (var request in requests) {
                builder.begin_object();

                // Timestamp
                builder.set_member_name("startedDateTime");
                builder.add_string_value(request.timestamp.format_iso8601());

                // Time (0 since we only capture requests, not responses)
                builder.set_member_name("time");
                builder.add_int_value(0);

                // Request
                builder.set_member_name("request");
                builder.begin_object();

                builder.set_member_name("method");
                builder.add_string_value(request.method);

                builder.set_member_name("url");
                builder.add_string_value(request.path);

                builder.set_member_name("httpVersion");
                builder.add_string_value("HTTP/1.1");

                // Headers
                builder.set_member_name("headers");
                builder.begin_array();
                request.headers.foreach((name, value) => {
                    builder.begin_object();
                    builder.set_member_name("name");
                    builder.add_string_value(name);
                    builder.set_member_name("value");
                    builder.add_string_value(value);
                    builder.end_object();
                });
                builder.end_array();

                // Query string
                builder.set_member_name("queryString");
                builder.begin_array();
                request.query_params.foreach((name, value) => {
                    builder.begin_object();
                    builder.set_member_name("name");
                    builder.add_string_value(name);
                    builder.set_member_name("value");
                    builder.add_string_value(value);
                    builder.end_object();
                });
                builder.end_array();

                // POST data
                if (request.body.length > 0) {
                    builder.set_member_name("postData");
                    builder.begin_object();
                    builder.set_member_name("mimeType");
                    builder.add_string_value(request.content_type ?? "application/octet-stream");
                    builder.set_member_name("text");
                    builder.add_string_value(request.body);
                    builder.end_object();
                }

                builder.set_member_name("headersSize");
                builder.add_int_value(-1);

                builder.set_member_name("bodySize");
                builder.add_int_value(request.content_length);

                builder.end_object(); // request

                // Response (empty since we only capture requests)
                builder.set_member_name("response");
                builder.begin_object();
                builder.set_member_name("status");
                builder.add_int_value(0);
                builder.set_member_name("statusText");
                builder.add_string_value("");
                builder.set_member_name("httpVersion");
                builder.add_string_value("HTTP/1.1");
                builder.set_member_name("headers");
                builder.begin_array();
                builder.end_array();
                builder.set_member_name("content");
                builder.begin_object();
                builder.set_member_name("size");
                builder.add_int_value(0);
                builder.set_member_name("mimeType");
                builder.add_string_value("");
                builder.end_object();
                builder.set_member_name("headersSize");
                builder.add_int_value(-1);
                builder.set_member_name("bodySize");
                builder.add_int_value(-1);
                builder.end_object(); // response

                // Cache
                builder.set_member_name("cache");
                builder.begin_object();
                builder.end_object();

                // Timings
                builder.set_member_name("timings");
                builder.begin_object();
                builder.set_member_name("send");
                builder.add_int_value(0);
                builder.set_member_name("wait");
                builder.add_int_value(0);
                builder.set_member_name("receive");
                builder.add_int_value(0);
                builder.end_object();

                builder.end_object(); // entry
            }

            builder.end_array(); // entries
            builder.end_object(); // log
            builder.end_object(); // root

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.pretty = true;
            generator.indent = 2;
            return generator.to_data(null);
        }

        /**
         * Export requests to CSV format.
         *
         * @param requests List of requests to export
         * @param include_headers Whether to include CSV header row
         * @return CSV formatted string
         */
        public static string export_to_csv(Gee.ArrayList<WebhookRequest> requests, bool include_headers = true) {
            var builder = new StringBuilder();

            // CSV Headers
            if (include_headers) {
                builder.append("ID,Timestamp,Method,Path,Content-Type,Content-Length,Body,Headers,Query Params,Starred\n");
            }

            // CSV Rows
            foreach (var request in requests) {
                builder.append(csv_escape(request.id));
                builder.append(",");
                builder.append(csv_escape(request.timestamp.format_iso8601()));
                builder.append(",");
                builder.append(csv_escape(request.method));
                builder.append(",");
                builder.append(csv_escape(request.path));
                builder.append(",");
                builder.append(csv_escape(request.content_type ?? ""));
                builder.append(",");
                builder.append(request.content_length.to_string());
                builder.append(",");
                builder.append(csv_escape(request.body));
                builder.append(",");
                builder.append(csv_escape(headers_to_string(request.headers)));
                builder.append(",");
                builder.append(csv_escape(query_params_to_string(request.query_params)));
                builder.append(",");
                builder.append(request.is_starred ? "true" : "false");
                builder.append("\n");
            }

            return builder.str;
        }

        /**
         * Export a request to cURL command format.
         *
         * @param request The request to export
         * @return cURL command string
         */
        public static string export_to_curl(WebhookRequest request) {
            var builder = new StringBuilder();
            builder.append("curl");

            // Method
            if (request.method != "GET") {
                builder.append(@" -X $(request.method)");
            }

            // Headers
            request.headers.foreach((name, value) => {
                builder.append(@" -H '$(name): $(value)'");
            });

            // Body
            if (request.body.length > 0) {
                // Escape single quotes in body
                string escaped_body = request.body.replace("'", "'\\''");
                builder.append(@" -d '$(escaped_body)'");
            }

            // URL (needs to be completed with actual host)
            builder.append(@" 'http://localhost:8000$(request.path)");

            // Add query parameters to URL if present
            if (request.query_params.size() > 0) {
                bool first = true;
                request.query_params.foreach((key, value) => {
                    builder.append(first ? "?" : "&");
                    builder.append(@"$(Uri.escape_string(key))=$(Uri.escape_string(value))");
                    first = false;
                });
            }
            builder.append("'");

            return builder.str;
        }

        /**
         * Export requests to JSON format.
         *
         * @param requests List of requests to export
         * @return JSON formatted string
         */
        public static string export_to_json(Gee.ArrayList<WebhookRequest> requests) {
            var builder = new Json.Builder();
            builder.begin_array();

            foreach (var request in requests) {
                builder.add_value(request.to_json());
            }

            builder.end_array();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.pretty = true;
            generator.indent = 2;
            return generator.to_data(null);
        }

        /**
         * Save exported data to a file.
         *
         * @param data The exported data string
         * @param file_path Path to save the file
         */
        public static void save_to_file(string data, string file_path) throws GLib.Error {
            var file = File.new_for_path(file_path);
            var output_stream = file.replace(null, false, FileCreateFlags.NONE);
            var data_stream = new DataOutputStream(output_stream);
            data_stream.put_string(data);
            data_stream.close();
        }

        /**
         * Escape a string for CSV format.
         */
        private static string csv_escape(string input) {
            // If contains comma, quote, or newline, wrap in quotes and escape quotes
            if (input.contains(",") || input.contains("\"") || input.contains("\n")) {
                return "\"" + input.replace("\"", "\"\"") + "\"";
            }
            return input;
        }

        /**
         * Convert headers hash table to string representation.
         */
        private static string headers_to_string(HashTable<string, string> headers) {
            var builder = new StringBuilder();
            headers.foreach((key, value) => {
                if (builder.len > 0) {
                    builder.append("; ");
                }
                builder.append(@"$(key): $(value)");
            });
            return builder.str;
        }

        /**
         * Convert query params hash table to string representation.
         */
        private static string query_params_to_string(HashTable<string, string> params) {
            var builder = new StringBuilder();
            params.foreach((key, value) => {
                if (builder.len > 0) {
                    builder.append("&");
                }
                builder.append(@"$(key)=$(value)");
            });
            return builder.str;
        }

        /**
         * Get file extension for export format.
         */
        public static string get_file_extension(ExportFormat format) {
            switch (format) {
                case ExportFormat.HAR:
                    return "har";
                case ExportFormat.CSV:
                    return "csv";
                case ExportFormat.CURL:
                    return "sh";
                case ExportFormat.JSON:
                    return "json";
                default:
                    return "txt";
            }
        }

        /**
         * Get MIME type for export format.
         */
        public static string get_mime_type(ExportFormat format) {
            switch (format) {
                case ExportFormat.HAR:
                case ExportFormat.JSON:
                    return "application/json";
                case ExportFormat.CSV:
                    return "text/csv";
                case ExportFormat.CURL:
                    return "application/x-sh";
                default:
                    return "text/plain";
            }
        }
    }
}
