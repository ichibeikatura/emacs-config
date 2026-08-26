;;; early-init.el --- Early initialization -*- lexical-binding: t -*-



(defvar my-saved-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)


;; 時刻表現の互換設定
;; Emacs 32 で current-time-list の既定値が nil になり、時刻が
;; (TICKS . HZ) の cons になった。時刻を (HIGH LOW USEC PSEC) の
;; リスト前提で分解する古いパッケージが軒並み
;; "Wrong type argument: listp, 1000000000" (1e9 = HZ) で落ちるため、
;; 旧形式に戻す。実例: DDSKK の skk-setup-shared-private-jisyo
;; (mapconcat で current-time を走査)、uptimes の uptimes-float-time。
;; before-init-time は early-init より前に C 側で記録済みなので変換する。
(setq current-time-list t)
(setq before-init-time (time-convert before-init-time 'list))

;; 基本ロード設定

;; .el が .elc より新しい場合、.el を読み込む（設定ミス防止）
(setq load-prefer-newer t)

;; パッケージ管理無効化（Straight/Elpaca用）
(setq package-enable-at-startup nil)
;; site-start.el は Emacs 31 から early-init.el より前に読まれるようになったため、
;; ここで site-run-file を nil にしても site-start.el の読み込みはもう止まらない
;; (止めるなら起動オプション --no-site-file)。今のビルドには site-start.el 自体が
;; 無いので実害は無く、default.el (init.el の後に読まれる) の抑止として残す。
(setq site-run-file nil)


;; GC最適化
(setq gc-cons-threshold (* 128 1024 1024))

;; 起動後の復帰処理
(add-hook 'after-init-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024))
            (setq file-name-handler-alist my-saved-file-name-handler-alist)
            (message "Emacs init time: %s" (emacs-init-time))))


;; Native Compilation 設定 (Emacs 28+)
(when (featurep 'native-compile)
  (setq native-comp-async-report-warnings-errors 'silent)
  (setq native-compile-prune-cache t)) ;; キャッシュの定期掃除


;; 起動時の表示抑制
(setq inhibit-startup-screen t)
(setq inhibit-startup-buffer-menu t)
(setq inhibit-default-init t)
(setq initial-scratch-message nil)
(setq initial-major-mode 'fundamental-mode)
(setq inhibit-startup-echo-area-message "mck") ;;"your-login-name"


;; 基本フレーム設定
(setq frame-inhibit-implied-resize t)
(setq default-frame-alist
      '((menu-bar-lines . 0)
        (tool-bar-lines . 0)
        (vertical-scroll-bars . nil)
        (horizontal-scroll-bars . nil)
        (internal-border-width . 0)
	(font . "Mplus 1 code-14")))

;; macOS固有設定
(when (eq system-type 'darwin)
  (setq ns-use-native-fullscreen nil)
  (setq ns-use-fullscreen-animation nil)
  ;; PATH は early-init で通す。Finder/Dock 起動時の PATH は
  ;; /usr/bin:/bin:/usr/sbin:/sbin しかなく、libgccjit が gcc ドライバとして
  ;; /usr/bin/gcc (Apple clang) を掴んで native-comp が
  ;; "error invoking gcc driver" で全滅するため。
  ;; init.el 側の elpaca-wait 中に非同期コンパイラが起動するので、
  ;; それより前 = early-init で設定する必要がある。
  (setenv "PATH" (concat (expand-file-name "~/.bin") ":"
                         (expand-file-name "~/.local/bin") ":"
                         "/usr/local/bin:/opt/homebrew/bin:"
                         (getenv "PATH")))
  (dolist (dir (list "/usr/local/bin" "/opt/homebrew/bin"
                     (expand-file-name "~/.local/bin")
                     (expand-file-name "~/.bin")))
    (add-to-list 'exec-path dir)))

;; フルスクリーン設定
(push '(fullscreen . maximized) default-frame-alist)


;; その他
;; マウスのダイアログ無効化
(setq use-dialog-box nil)
(setq use-file-dialog nil)

(provide 'early-init)
;;; early-init.el ends here
