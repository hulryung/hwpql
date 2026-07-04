//! C FFI bindings for rhwp HWP parser.
//!
//! hwpql (macOS Quick Look plugin) 에서 사용하는 4개 함수를 노출한다.

use std::ffi::CString;
use std::os::raw::c_char;
use std::panic::AssertUnwindSafe;

const HWP_OK: i32 = 0;
const HWP_ERROR_NULL_POINTER: i32 = -1;
const HWP_ERROR_PARSE_FAILED: i32 = -2;
const HWP_ERROR_PANIC: i32 = -3;
const HWP_ERROR_NO_PREVIEW_IMAGE: i32 = -4;
const HWP_ERROR_RENDER_FAILED: i32 = -5;

/// HWP/HWPX 파일을 파싱하여 SVG가 포함된 HTML 문자열로 변환한다.
///
/// 각 페이지를 SVG로 렌더링한 후, 최소한의 HTML로 감싸서 반환한다.
/// 기존 hwp_parse_to_html과 동일한 시그니처를 유지한다.
#[no_mangle]
pub extern "C" fn hwp_parse_to_html(
    data: *const u8,
    data_len: usize,
    out_html: *mut *mut c_char,
    out_len: *mut usize,
) -> i32 {
    if data.is_null() || out_html.is_null() || out_len.is_null() {
        return HWP_ERROR_NULL_POINTER;
    }

    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let slice = unsafe { std::slice::from_raw_parts(data, data_len) };

        let core = match rhwp::DocumentCore::from_bytes(slice) {
            Ok(c) => c,
            Err(_) => return Err(HWP_ERROR_PARSE_FAILED),
        };

        let page_count = core.page_count();
        let mut svg_pages = Vec::with_capacity(page_count as usize);

        for i in 0..page_count {
            match core.render_page_svg_native(i) {
                Ok(svg) => svg_pages.push(svg),
                Err(_) => return Err(HWP_ERROR_PARSE_FAILED),
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
body {{ margin: 0; padding: 20px; background: #eee; }}
.page {{ background: white; box-shadow: 0 2px 8px rgba(0,0,0,0.15); width: fit-content; margin: 0 auto; }}
.page + .page {{ margin-top: 20px; }}
.page svg {{ display: block; }}
@media (prefers-color-scheme: dark) {{
  body {{ background: #1e1e1e; }}
}}
@page {{ size: A4; margin: 0; }}
@media print {{
  body {{ margin: 0; padding: 0; background: white; }}
  .page {{ box-shadow: none; margin: 0; width: auto; page-break-after: always; break-after: page; }}
  .page:last-child {{ page-break-after: auto; break-after: auto; }}
  .page svg {{ max-width: none; width: 100%; height: auto; }}
}}
</style></head><body>
{}
</body></html>"#,
            pages_html
        );

        Ok(html)
    }));

    match result {
        Ok(Ok(html)) => {
            let c_str = match CString::new(html) {
                Ok(s) => s,
                Err(_) => return HWP_ERROR_PARSE_FAILED,
            };
            unsafe {
                *out_len = c_str.as_bytes().len();
                *out_html = c_str.into_raw();
            }
            HWP_OK
        }
        Ok(Err(code)) => code,
        Err(_) => HWP_ERROR_PANIC,
    }
}

/// HWP/HWPX 파일에서 미리보기 이미지(PrvImage)를 추출한다.
#[no_mangle]
pub extern "C" fn hwp_get_preview_image(
    data: *const u8,
    data_len: usize,
    out_data: *mut *mut u8,
    out_len: *mut usize,
    out_format: *mut *mut c_char,
) -> i32 {
    if data.is_null() || out_data.is_null() || out_len.is_null() || out_format.is_null() {
        return HWP_ERROR_NULL_POINTER;
    }

    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let slice = unsafe { std::slice::from_raw_parts(data, data_len) };

        match rhwp::parser::extract_thumbnail_only(slice) {
            Some(thumb) => {
                let format = match CString::new(thumb.format) {
                    Ok(s) => s,
                    Err(_) => return Err(HWP_ERROR_PARSE_FAILED),
                };
                let mut boxed = thumb.data.into_boxed_slice();
                let len = boxed.len();
                let ptr = boxed.as_mut_ptr();
                std::mem::forget(boxed);

                Ok((ptr, len, format))
            }
            None => Err(HWP_ERROR_NO_PREVIEW_IMAGE),
        }
    }));

    match result {
        Ok(Ok((ptr, len, format))) => {
            unsafe {
                *out_data = ptr;
                *out_len = len;
                *out_format = format.into_raw();
            }
            HWP_OK
        }
        Ok(Err(code)) => code,
        Err(_) => HWP_ERROR_PANIC,
    }
}

/// HWP/HWPX 파일을 PDF로 변환한다.
///
/// `page_num`이 음수이면 전체 문서를 하나의 PDF로 렌더링하고, 0 이상이면
/// 해당 페이지 한 장만 PDF로 렌더링한다. 페이지 인덱스가 범위를 벗어나면
/// HWP_ERROR_RENDER_FAILED를 반환한다.
#[no_mangle]
pub extern "C" fn hwp_render_pdf(
    data: *const u8,
    data_len: usize,
    page_num: i32,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if data.is_null() || out_data.is_null() || out_len.is_null() {
        return HWP_ERROR_NULL_POINTER;
    }

    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let slice = unsafe { std::slice::from_raw_parts(data, data_len) };

        let core = match rhwp::DocumentCore::from_bytes(slice) {
            Ok(c) => c,
            Err(_) => return Err(HWP_ERROR_PARSE_FAILED),
        };

        let pdf = if page_num < 0 {
            core.render_document_pdf_native()
        } else {
            core.render_page_pdf_native(page_num as u32)
        };

        match pdf {
            Ok(bytes) => {
                let mut boxed = bytes.into_boxed_slice();
                let len = boxed.len();
                let ptr = boxed.as_mut_ptr();
                std::mem::forget(boxed);

                Ok((ptr, len))
            }
            Err(_) => Err(HWP_ERROR_RENDER_FAILED),
        }
    }));

    match result {
        Ok(Ok((ptr, len))) => {
            unsafe {
                *out_data = ptr;
                *out_len = len;
            }
            HWP_OK
        }
        Ok(Err(code)) => code,
        Err(_) => HWP_ERROR_PANIC,
    }
}

/// Rust가 할당한 C 문자열을 해제한다.
#[no_mangle]
pub extern "C" fn hwp_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Rust가 할당한 바이트 버퍼를 해제한다.
#[no_mangle]
pub extern "C" fn hwp_free_bytes(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        unsafe {
            let _ = Vec::from_raw_parts(ptr, len, len);
        }
    }
}
