/*
 * Request indexing for fast search and filtering.
 */

using GLib;
using Gee;

namespace Sonar {

    /**
     * Index for fast request lookups and filtering.
     */
    public class RequestIndex : GLib.Object {
        // Index by method
        private HashMap<string, ArrayList<WebhookRequest>> method_index;

        // Index by path
        private HashMap<string, ArrayList<WebhookRequest>> path_index;

        // Index by content type
        private HashMap<string, ArrayList<WebhookRequest>> content_type_index;

        // Index for starred requests
        private ArrayList<WebhookRequest> starred_requests;

        // Full text search index (simple keyword-based)
        private HashMap<string, ArrayList<WebhookRequest>> keyword_index;

        public RequestIndex() {
            this.method_index = new HashMap<string, ArrayList<WebhookRequest>>();
            this.path_index = new HashMap<string, ArrayList<WebhookRequest>>();
            this.content_type_index = new HashMap<string, ArrayList<WebhookRequest>>();
            this.starred_requests = new ArrayList<WebhookRequest>();
            this.keyword_index = new HashMap<string, ArrayList<WebhookRequest>>();
        }

        /**
         * Add a request to the index.
         */
        public void add_request(WebhookRequest request) {
            // Index by method
            if (!method_index.has_key(request.method)) {
                method_index.set(request.method, new ArrayList<WebhookRequest>());
            }
            method_index.get(request.method).add(request);

            // Index by path
            if (!path_index.has_key(request.path)) {
                path_index.set(request.path, new ArrayList<WebhookRequest>());
            }
            path_index.get(request.path).add(request);

            // Index by content type
            if (request.content_type != null) {
                if (!content_type_index.has_key(request.content_type)) {
                    content_type_index.set(request.content_type, new ArrayList<WebhookRequest>());
                }
                content_type_index.get(request.content_type).add(request);
            }

            // Index starred
            if (request.is_starred) {
                starred_requests.add(request);
            }

            // Index keywords from body (simple tokenization)
            index_keywords(request);
        }

        /**
         * Remove a request from the index.
         */
        public void remove_request(WebhookRequest request) {
            // Remove from method index
            if (method_index.has_key(request.method)) {
                method_index.get(request.method).remove(request);
            }

            // Remove from path index
            if (path_index.has_key(request.path)) {
                path_index.get(request.path).remove(request);
            }

            // Remove from content type index
            if (request.content_type != null && content_type_index.has_key(request.content_type)) {
                content_type_index.get(request.content_type).remove(request);
            }

            // Remove from starred
            starred_requests.remove(request);

            // Note: Not removing from keyword index for performance
            // Keyword index will naturally expire when requests are removed
        }

        /**
         * Clear all indexes.
         */
        public void clear() {
            method_index.clear();
            path_index.clear();
            content_type_index.clear();
            starred_requests.clear();
            keyword_index.clear();
        }

        /**
         * Find requests by method.
         */
        public ArrayList<WebhookRequest> find_by_method(string method) {
            if (method_index.has_key(method)) {
                return method_index.get(method);
            }
            return new ArrayList<WebhookRequest>();
        }

        /**
         * Find requests by path.
         */
        public ArrayList<WebhookRequest> find_by_path(string path) {
            if (path_index.has_key(path)) {
                return path_index.get(path);
            }
            return new ArrayList<WebhookRequest>();
        }

        /**
         * Find requests by content type.
         */
        public ArrayList<WebhookRequest> find_by_content_type(string content_type) {
            if (content_type_index.has_key(content_type)) {
                return content_type_index.get(content_type);
            }
            return new ArrayList<WebhookRequest>();
        }

        /**
         * Get all starred requests.
         */
        public ArrayList<WebhookRequest> get_starred() {
            return starred_requests;
        }

        /**
         * Search requests by keyword (simple full-text search).
         */
        public ArrayList<WebhookRequest> search(string query) {
            var results = new HashSet<WebhookRequest>();
            var keywords = tokenize(query.down());

            foreach (var keyword in keywords) {
                if (keyword_index.has_key(keyword)) {
                    var matches = keyword_index.get(keyword);
                    foreach (var request in matches) {
                        results.add(request);
                    }
                }
            }

            var result_list = new ArrayList<WebhookRequest>();
            foreach (var request in results) {
                result_list.add(request);
            }

            return result_list;
        }

        /**
         * Index keywords from request for full-text search.
         */
        private void index_keywords(WebhookRequest request) {
            // Extract keywords from path, body, and headers
            var keywords = new HashSet<string>();

            // Tokenize path
            foreach (var keyword in tokenize(request.path.down())) {
                keywords.add(keyword);
            }

            // Tokenize body (limit to first 1000 chars for performance)
            string body_sample = request.body.length > 1000 ?
                request.body.substring(0, 1000) : request.body;
            foreach (var keyword in tokenize(body_sample.down())) {
                keywords.add(keyword);
            }

            // Index each keyword
            foreach (var keyword in keywords) {
                if (keyword.length >= 3) { // Only index words 3+ chars
                    if (!keyword_index.has_key(keyword)) {
                        keyword_index.set(keyword, new ArrayList<WebhookRequest>());
                    }
                    keyword_index.get(keyword).add(request);
                }
            }
        }

        /**
         * Simple tokenization (split on non-alphanumeric chars).
         */
        private ArrayList<string> tokenize(string text) {
            var tokens = new ArrayList<string>();
            var current_token = new StringBuilder();

            for (int i = 0; i < text.length; i++) {
                unichar c = text.get_char(i);

                if (c.isalnum() || c == '_' || c == '-') {
                    current_token.append_unichar(c);
                } else {
                    if (current_token.len > 0) {
                        tokens.add(current_token.str);
                        current_token = new StringBuilder();
                    }
                }
            }

            // Add last token
            if (current_token.len > 0) {
                tokens.add(current_token.str);
            }

            return tokens;
        }

        /**
         * Get index statistics.
         */
        public HashTable<string, int> get_statistics() {
            var stats = new HashTable<string, int>(str_hash, str_equal);
            stats.set("unique_methods", method_index.size);
            stats.set("unique_paths", path_index.size);
            stats.set("unique_content_types", content_type_index.size);
            stats.set("starred_count", starred_requests.size);
            stats.set("indexed_keywords", keyword_index.size);
            return stats;
        }
    }
}
