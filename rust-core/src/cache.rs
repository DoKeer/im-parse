use crate::ast::RootNode;
use hashbrown::HashMap;
use std::time::{Duration, Instant};

/// 缓存条目
struct CacheEntry<T> {
    value: T,
    created_at: Instant,
    ttl: Duration,
}

impl<T> CacheEntry<T> {
    fn new(value: T, ttl: Duration) -> Self {
        Self {
            value,
            created_at: Instant::now(),
            ttl,
        }
    }

    fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.ttl
    }
}

/// AST 缓存
pub struct ASTCache {
    cache: HashMap<String, CacheEntry<RootNode>>,
    default_ttl: Duration,
}

impl ASTCache {
    pub fn new(default_ttl: Duration) -> Self {
        Self {
            cache: HashMap::new(),
            default_ttl,
        }
    }

    pub fn get(&self, key: &str) -> Option<&RootNode> {
        self.cache.get(key).and_then(|entry| {
            if entry.is_expired() {
                None
            } else {
                Some(&entry.value)
            }
        })
    }

    pub fn set(&mut self, key: String, value: RootNode, ttl: Option<Duration>) {
        let entry = CacheEntry::new(value, ttl.unwrap_or(self.default_ttl));
        self.cache.insert(key, entry);
    }

    pub fn remove(&mut self, key: &str) {
        self.cache.remove(key);
    }

    pub fn clear(&mut self) {
        self.cache.clear();
    }

    pub fn cleanup_expired(&mut self) {
        self.cache.retain(|_, entry| !entry.is_expired());
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }
}

impl Default for ASTCache {
    fn default() -> Self {
        Self::new(Duration::from_secs(3600)) // 默认 1 小时
    }
}

/// 高度缓存
pub struct HeightCache {
    cache: HashMap<String, CacheEntry<f32>>,
    default_ttl: Duration,
}

impl HeightCache {
    pub fn new(default_ttl: Duration) -> Self {
        Self {
            cache: HashMap::new(),
            default_ttl,
        }
    }

    pub fn get(&self, key: &str) -> Option<f32> {
        self.cache.get(key).and_then(|entry| {
            if entry.is_expired() {
                None
            } else {
                Some(entry.value)
            }
        })
    }

    pub fn set(&mut self, key: String, value: f32, ttl: Option<Duration>) {
        let entry = CacheEntry::new(value, ttl.unwrap_or(self.default_ttl));
        self.cache.insert(key, entry);
    }

    pub fn remove(&mut self, key: &str) {
        self.cache.remove(key);
    }

    pub fn clear(&mut self) {
        self.cache.clear();
    }

    pub fn cleanup_expired(&mut self) {
        self.cache.retain(|_, entry| !entry.is_expired());
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }
}

impl Default for HeightCache {
    fn default() -> Self {
        Self::new(Duration::from_secs(3600)) // 默认 1 小时
    }
}

/// 生成缓存键
pub fn generate_cache_key(content: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let mut hasher = DefaultHasher::new();
    content.hash(&mut hasher);
    format!("{:x}", hasher.finish())
}

/// 生成高度缓存键
pub fn generate_height_cache_key(ast_key: &str, width: f32) -> String {
    format!("{}:{}", ast_key, width)
}

