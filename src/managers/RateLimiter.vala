/*
 * Rate limiter for preventing DoS attacks using token bucket algorithm.
 */

using GLib;
using Gee;

namespace Sonar {

    /**
     * Token bucket for rate limiting individual sources.
     */
    private class TokenBucket : Object {
        private int64 tokens;
        private int64 last_refill_time;
        private int capacity;
        private int refill_rate;

        public TokenBucket(int capacity, int refill_rate) {
            this.capacity = capacity;
            this.refill_rate = refill_rate;
            this.tokens = capacity;
            this.last_refill_time = get_monotonic_time();
        }

        /**
         * Try to consume a token. Returns true if allowed, false if rate limited.
         */
        public bool consume() {
            refill();

            if (tokens > 0) {
                tokens--;
                return true;
            }

            return false;
        }

        /**
         * Refill tokens based on elapsed time.
         */
        private void refill() {
            int64 now = get_monotonic_time();
            int64 elapsed_micros = now - last_refill_time;
            int64 elapsed_seconds = elapsed_micros / 1000000;

            if (elapsed_seconds > 0) {
                int64 tokens_to_add = elapsed_seconds * refill_rate;
                tokens = int64.min(capacity, tokens + tokens_to_add);
                last_refill_time = now;
            }
        }

        /**
         * Reset the bucket to full capacity.
         */
        public void reset() {
            tokens = capacity;
            last_refill_time = get_monotonic_time();
        }
    }

    /**
     * Rate limiter using token bucket algorithm with LRU eviction.
     */
    public class RateLimiter : Object {
        private HashMap<string, TokenBucket> buckets;
        private Gee.LinkedList<string> lru_queue;
        private int max_buckets;
        private int requests_per_second;
        private int burst_size;
        private bool enabled;
        private Mutex lock;

        /**
         * Create a new rate limiter.
         *
         * @param requests_per_second Maximum requests per second per source
         * @param burst_size Maximum burst size (bucket capacity)
         * @param max_buckets Maximum number of tracked sources (LRU eviction)
         */
        public RateLimiter(int requests_per_second = 100, int burst_size = 200, int max_buckets = 1000) {
            this.requests_per_second = requests_per_second;
            this.burst_size = burst_size;
            this.max_buckets = max_buckets;
            this.enabled = false;
            this.buckets = new HashMap<string, TokenBucket>();
            this.lru_queue = new Gee.LinkedList<string>();
            this.lock = Mutex();
        }

        /**
         * Enable or disable rate limiting.
         */
        public void set_enabled(bool enabled) {
            this.lock.lock();
            this.enabled = enabled;
            this.lock.unlock();
            debug("Rate limiting %s", enabled ? "enabled" : "disabled");
        }

        /**
         * Check if rate limiting is enabled.
         */
        public bool is_enabled() {
            this.lock.lock();
            bool result = this.enabled;
            this.lock.unlock();
            return result;
        }

        /**
         * Configure rate limit parameters.
         */
        public void configure(int requests_per_second, int burst_size) {
            this.lock.lock();
            this.requests_per_second = requests_per_second;
            this.burst_size = burst_size;

            // Update existing buckets with new parameters
            foreach (var bucket in buckets.values) {
                bucket.reset();
            }

            this.lock.unlock();
            debug("Rate limiter configured: %d req/s, burst: %d", requests_per_second, burst_size);
        }

        /**
         * Check if a request from the given identifier should be allowed.
         *
         * @param identifier Unique identifier for the source (e.g., IP address, path)
         * @return true if request is allowed, false if rate limited
         */
        public bool check_rate_limit(string identifier) {
            if (!enabled) {
                return true;
            }

            this.lock.lock();

            // Get or create bucket for this identifier
            TokenBucket? bucket = buckets.get(identifier);
            if (bucket == null) {
                bucket = new TokenBucket(burst_size, requests_per_second);
                buckets.set(identifier, bucket);
                lru_queue.offer_tail(identifier);

                // Evict oldest bucket if we exceed max_buckets
                if (buckets.size > max_buckets) {
                    string? oldest = lru_queue.poll_head();
                    if (oldest != null) {
                        buckets.unset(oldest);
                    }
                }
            } else {
                // Move to end of LRU queue (most recently used)
                lru_queue.remove(identifier);
                lru_queue.offer_tail(identifier);
            }

            bool allowed = bucket.consume();

            this.lock.unlock();

            if (!allowed) {
                warning("Rate limit exceeded for identifier: %s", identifier);
            }

            return allowed;
        }

        /**
         * Reset rate limit for a specific identifier.
         */
        public void reset(string identifier) {
            this.lock.lock();

            TokenBucket? bucket = buckets.get(identifier);
            if (bucket != null) {
                bucket.reset();
                debug("Rate limit reset for: %s", identifier);
            }

            this.lock.unlock();
        }

        /**
         * Clear all rate limit data.
         */
        public void clear_all() {
            this.lock.lock();
            buckets.clear();
            lru_queue.clear();
            this.lock.unlock();
            debug("All rate limit data cleared");
        }

        /**
         * Get current statistics.
         */
        public HashTable<string, Value?> get_statistics() {
            this.lock.lock();

            var stats = new HashTable<string, Value?>(str_hash, str_equal);
            stats.set("enabled", enabled);
            stats.set("tracked_sources", buckets.size);
            stats.set("requests_per_second", requests_per_second);
            stats.set("burst_size", burst_size);
            stats.set("max_buckets", max_buckets);

            this.lock.unlock();

            return stats;
        }
    }
}
