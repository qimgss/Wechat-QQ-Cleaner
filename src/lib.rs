// src/lib.rs
use std::fs;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use std::io;

/// 清理微信缓存
#[no_mangle]
pub extern "C" fn clean_wechat_cache() -> i32 {
    println!("Cleaning WeChat cache...");
    
    let paths = [
        "/data/data/com.tencent.mm/cache/",
        "/sdcard/Android/data/com.tencent.mm/cache/",
    ];
    
    let mut total_cleaned = 0;
    
    for path_str in &paths {
        let path = Path::new(path_str);
        if let Ok(freed) = clean_directory(path, 12 * 3600) {
            total_cleaned += freed;
        }
    }
    
    println!("Cleaned {} bytes from WeChat", total_cleaned);
    0
}

/// 清理QQ缓存
#[no_mangle]
pub extern "C" fn clean_qq_cache() -> i32 {
    println!("Cleaning QQ cache...");
    
    let paths = [
        "/data/data/com.tencent.mobileqq/cache/",
        "/sdcard/Android/data/com.tencent.mobileqq/cache/",
    ];
    
    let mut total_cleaned = 0;
    
    for path_str in &paths {
        let path = Path::new(path_str);
        if let Ok(freed) = clean_directory(path, 12 * 3600) {
            total_cleaned += freed;
        }
    }
    
    println!("Cleaned {} bytes from QQ", total_cleaned);
    0
}

/// 清理所有缓存
#[no_mangle]
pub extern "C" fn clean_all_cache() -> i32 {
    println!("Starting full cleanup...");
    
    let wechat_result = clean_wechat_cache();
    let qq_result = clean_qq_cache();
    
    if wechat_result == 0 && qq_result == 0 {
        println!("Cleanup completed successfully");
        0
    } else {
        println!("Cleanup completed with errors");
        -1
    }
}

/// 清理指定目录
fn clean_directory(path: &Path, max_age_seconds: u64) -> io::Result<u64> {
    if !path.exists() {
        return Ok(0);
    }
    
    let mut total_freed: u64 = 0;
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    if let Ok(entries) = fs::read_dir(path) {
        for entry in entries {
            if let Ok(entry) = entry {
                if let Ok(metadata) = entry.metadata() {
                    if metadata.is_file() {
                        if let Ok(modified) = metadata.modified() {
                            let modified_secs = modified
                                .duration_since(UNIX_EPOCH)
                                .unwrap()
                                .as_secs();
                            
                            if now - modified_secs > max_age_seconds {
                                match fs::remove_file(entry.path()) {
                                    Ok(_) => {
                                        total_freed += metadata.len();
                                    }
                                    Err(_) => {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Ok(total_freed)
}