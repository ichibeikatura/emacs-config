# emacs-config

Elpaca + use-package 構成の Emacs 設定。日本語執筆向け（SKK, Dvorak）、macOS 環境。

## 動作環境

- Emacs 29+（Native Compilation 対応）
- macOS（Homebrew 環境）
- US 配列

## 主な特徴

### パッケージ管理

[Elpaca](https://github.com/progfolio/elpaca) による非同期パッケージ管理。use-package と統合。

### 日本語入力

- **DDSKK** + **yaskkserv2**による日本語入力
- **skk-lookup** による EPWING 辞書連携（広辞苑、大辞林、日本史辞典など）[Lookup 1.4+media](http://ikazuhiro.s206.xrea.com/staticpages/index.php/lookup)対応済み。

skk-lookup.el と skk-bayesian.el を使いたい場合は site-lisp に、 "bskk" はパスの通った場所("~/bin" 等)に入れておく。

### キーボード配列

Dvorak 配列。`dvorak` / `qwerty` コマンドで切り替え可能。SKK の変換候補キーも Dvorak 配置（`a o e u i d h t n s -`）に対応。US 配列用。

### 執筆支援

- **nhg-minor-mode** - 日本語執筆支援
- **year-convert** - 西暦・和暦変換
- **kreplace** - 旧字体→新字体変換
- **[Lookup 1.4+media](http://ikazuhiro.s206.xrea.com/staticpages/index.php/lookup)** - EPWING 辞書検索


### 依存関係（Homebrew）

```bash
brew install ripgrep fd coreutils pngpaste
```

### フォント

以下のいずれかをインストール：
- [M+ 1mn](https://github.com/coz-m/MPLUS_FONTS)
- [PlemolJP](https://github.com/yuru7/PlemolJP)

### SKK 辞書サーバー

[yaskkserv2](https://github.com/wachikun/yaskkserv2) を UTF-8 モードで起動しておく（ポート 1178）。

```bash
yaskkserv2 --google-japanese-input=last --google-suggest --google-cache-filename=/tmp/yaskkserv2.cache /tmp/dictionary.yaskkserv2
```

### Bibi

[Bibi](https://bibi.epub.link) :EPUB リーダ。

### EPUB 変換用スクリプト

[tategaki-epub-script](https://github.com/ichibeikatura/tategaki-epub-script) :縦書き EPUB 変換スクリプト。この設定で使う場合は "chmod +x"。

EPUBリーダで更新が反映されない場合はキャッシュを消して対処する。

## 主要キーバインド

| キー | 機能 |
|------|------|
| `M-o` | SKK モード切替 |
| `C-s` | consult-line（バッファ内検索） |
| `C-'` | consult-buffer |
| `C-x C-y` | 最近開いたファイル |
| `C-c C-s` | consult-ripgrep |
| `C-c S` | deadgrep |
| `C-x g` | magit-status |
| `C-x l` | lookup（辞書検索） |
| `C-M-=` | 西暦・和暦変換 |
| `C-c C-y` | 旧字体→新字体変換 |
| `C-c n` | imenu-list |
| `C-c t` | アウトラインメニュー |
| `M-{` / `M-}` | タブ移動 |

## ライセンス

MIT
