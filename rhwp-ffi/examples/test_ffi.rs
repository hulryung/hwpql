//! FFI 함수의 내부 로직을 직접 테스트한다.
//! HTML 파일을 생성하여 브라우저에서 확인할 수 있다.

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: test_ffi <file.hwp|file.hwpx>");
        std::process::exit(1);
    }

    let data = std::fs::read(&args[1]).expect("Failed to read file");
    println!("File: {} ({} bytes)", args[1], data.len());

    // Parse and render to SVG-in-HTML (same logic as FFI)
    println!("\nParsing...");
    let core = rhwp::DocumentCore::from_bytes(&data).expect("Parse failed");
    let page_count = core.page_count();
    println!("Pages: {}", page_count);

    let mut svg_pages = Vec::new();
    for i in 0..page_count {
        match core.render_page_svg_native(i) {
            Ok(svg) => {
                println!("  Page {}: {} bytes SVG", i, svg.len());
                svg_pages.push(svg);
            }
            Err(e) => eprintln!("  Page {} render error: {:?}", i, e),
        }
    }

    let pages_html: String = svg_pages
        .iter()
        .map(|svg| format!("<div class=\"page\">{}</div>", svg))
        .collect::<Vec<_>>()
        .join("\n");

    let html = format!(
        r#"<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body {{ margin: 0; padding: 20px; background: #eee; display: flex; flex-direction: column; align-items: center; gap: 20px; }}
.page {{ background: white; box-shadow: 0 2px 8px rgba(0,0,0,0.15); }}
.page svg {{ display: block; max-width: 100%; height: auto; }}
</style></head><body>
{}
</body></html>"#,
        pages_html
    );

    let out_path = "/tmp/hwpql-preview.html";
    std::fs::write(out_path, &html).expect("Failed to write HTML");
    println!("\nHTML written to {} ({} bytes)", out_path, html.len());

    // Thumbnail
    println!("\n--- Thumbnail ---");
    match rhwp::parser::extract_thumbnail_only(&data) {
        Some(thumb) => {
            println!("Thumbnail: {} format, {} bytes, {}x{}",
                thumb.format, thumb.data.len(), thumb.width, thumb.height);
        }
        None => println!("No thumbnail found"),
    }
}
