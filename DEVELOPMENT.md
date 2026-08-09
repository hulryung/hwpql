# 개발 가이드

이 문서는 HWPQuickLook을 직접 빌드·서명·배포하거나 rhwp 버전을 갱신할 때 참고하는 자료입니다. 일반 사용자는 [README](README.md)의 설치 안내만 따르면 됩니다.

## 직접 빌드하기

Xcode 15 이상과 [Rust toolchain](https://rustup.rs/)이 필요합니다. `libs/libhwp_ffi.a`는 122 MiB로 GitHub의 100 MiB 파일 제한을 넘어 git에서 추적하지 않으므로, 클론 직후 한 번은 직접 빌드해야 합니다 (약 1분).

```bash
./scripts/build-rust.sh
xcodebuild -project HWPQuickLook.xcodeproj -scheme HWPQuickLook -configuration Release build
```

빌드 결과를 시스템에 반영하려면 `/Applications`에 복사 후 Quick Look 캐시를 리셋합니다.

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/HWPQuickLook-*/Build/Products/Release/HWPQuickLook.app /Applications/
qlmanage -r && qlmanage -r cache
```

`libs/rhwp.lock`이 빌드에 사용된 rhwp 커밋과 산출물 sha256을 기록하므로, 같은 lock으로 빌드하면 동일한 라이브러리가 재현됩니다.

## 릴리스 빌드 (서명·공증·DMG)

전체 릴리스 파이프라인이 `scripts/release.sh`로 자동화되어 있습니다.

```bash
bash scripts/release.sh
```

수행 단계:

1. `libs/libhwp_ffi.a` 해시가 `libs/rhwp.lock` 기록과 일치하는지 검증
2. Xcode Release 빌드
3. `.app` 공증 제출 → Accepted → staple
4. `hdiutil`로 DMG 생성 (`/Applications` 심볼릭링크 포함)
5. DMG Developer ID 서명 (secure timestamp)
6. DMG 공증 → staple → `spctl` 검증

산출물: `build/HWPQuickLook-vX.Y.Z.dmg`

### 최초 1회 셋업

`notarytool` 키체인 프로필을 미리 저장해 두어야 합니다.

```bash
xcrun notarytool store-credentials "HWPQuickLook" \
  --apple-id <your-apple-id> \
  --team-id <your-team-id> \
  --password <app-specific-password>
```

`NOTARY_PROFILE` 환경변수로 다른 프로필 이름을 지정할 수 있습니다 (기본값: `HWPQuickLook`).

### Homebrew tap 갱신

DMG 공증이 끝나고 `gh release create`로 릴리스를 만든 뒤, `hulryung/homebrew-tap` 의 `Casks/hwpquicklook.rb`에서 `version`과 `sha256`을 새 DMG 값으로 업데이트해 push 하면 `brew install --cask hulryung/tap/hwpquicklook`이 즉시 새 버전을 받습니다.

## Rust 라이브러리 재빌드

FFI 래퍼(`rhwp-ffi/` 크레이트)가 이 저장소에 포함되어 있고, rhwp는 `rhwp-ffi/Cargo.toml`에서 **특정 커밋을 git dependency로 고정**합니다. 클론 직후 한 번, 그리고 rhwp 버전 업그레이드나 FFI 인터페이스 변경 시마다 재빌드가 필요합니다.

### 요구사항

- [Rust toolchain](https://rustup.rs/)

### rhwp 버전 업데이트 절차

1. `rhwp-ffi/Cargo.toml`의 `rev = "..."` 값을 원하는 새 커밋 SHA로 변경
2. `./scripts/build-rust.sh` 실행

스크립트가 자동으로:

- `rhwp-ffi` 크레이트를 `cargo build --release` (cargo가 rhwp를 pinned rev로 fetch)
- 산출물을 `libs/libhwp_ffi.a`로 복사
- `libs/rhwp.lock`에 repo/commit/built_at/sha256/size 기록

### 산출물 검증

`scripts/release.sh`는 빌드 시작 전 `libs/libhwp_ffi.a`의 sha256이 `libs/rhwp.lock` 기록과 일치하는지 확인합니다. 불일치면 `scripts/build-rust.sh`를 다시 실행하라는 메시지와 함께 중단됩니다. 누군가 `.a`만 교체하고 rhwp.lock을 업데이트하지 않은 상태를 원천 차단하기 위함입니다.

## 프로젝트 구조

```
HWPQuickLook/              # 독립 뷰어 앱 (SwiftUI + AppKit, UTI 등록 호스트)
├── Assets.xcassets/       # AppIcon 등 리소스
├── AppDelegate.swift      # SwiftUI App + NSApplicationDelegate
└── Info.plist             # UTI 선언 및 Document Types

HWPPreviewer/              # Quick Look 프리뷰 익스텐션 (.appex)
├── PreviewProvider.swift  # QLPreviewProvider 구현
└── Info.plist             # QLSupportedContentTypes

HWPThumbnailer/            # Finder 썸네일 익스텐션 (.appex)
├── ThumbnailProvider.swift
└── Info.plist

Shared/BridgingHeader.h    # Rust FFI 선언 (hwp_parse_to_html 등)

rhwp-ffi/                  # Rust FFI 래퍼 크레이트
├── src/lib.rs             # hwp_parse_to_html / hwp_get_preview_image 구현
└── Cargo.toml             # rhwp를 git rev로 pinning

libs/
├── libhwp_ffi.a           # rhwp-ffi 정적 라이브러리 (gitignored — build-rust.sh로 생성)
└── rhwp.lock              # 빌드 메타데이터 (commit SHA, sha256, size)

scripts/
├── build-rust.sh          # rhwp-ffi 빌드 + rhwp.lock 갱신
├── make-icon.swift        # 앱 아이콘 프로그래매틱 생성 (CoreGraphics)
└── release.sh             # 릴리스 파이프라인 (해시 검증 + 서명·공증·DMG)
```

## 테스트 & 문제 해결

### 프리뷰·썸네일 수동 검증

```bash
# Quick Look 프리뷰
qlmanage -p ~/path/to/file.hwp

# 썸네일 (모던 QLThumbnailProvider 강제 호출에는 -x 필요)
qlmanage -t -x -s 512 -o /tmp ~/path/to/file.hwp
```

Finder에서는 `-x` 없이도 자동으로 익스텐션이 호출됩니다.

### 설치 후 Finder에서 변경이 안 보일 때

Launch Services / Quick Look 캐시를 재구축하고 Finder를 재시작합니다.

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -kill -r -domain local -domain system -domain user
qlmanage -r && qlmanage -r cache
killall Finder
```

### 한컴오피스와 UTI 충돌

한컴오피스가 설치되어 있다면 동일 UTI를 소유하려고 경쟁할 수 있습니다. HWPQuickLook은 `LSHandlerRank=Owner`로 선점하지만, 한컴오피스를 제거했는데도 효과가 없으면 휴지통을 비우고 `lsregister`를 재구축하세요.
