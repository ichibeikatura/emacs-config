;;; early-init.el --- Early initialization -*- lexical-binding: t -*-

;;; Commentary:
;; Emacs 27+ 用。GUI構築前設定、GC調整、File Handlerハックを行う。

;;; Code:

;; ============================================================
;; 【高速化】File Name Handlerの一時無効化
;; ============================================================
;; 起動時のファイル読み込み（require等）で正規表現マッチを走らせない
(defvar my-saved-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; ============================================================
;; 基本ロード設定
;; ============================================================
;; .el が .elc より新しい場合、.el を読み込む（設定ミス防止）
(setq load-prefer-newer t)

;; パッケージ管理無効化（Straight/Elpaca用）
(setq package-enable-at-startup nil)
(setq site-run-file nil) ;; default.el 等を読まない

;; ============================================================
;; GC・プロセス最適化
;; ============================================================
(setq gc-cons-threshold (* 128 1024 1024))
(setq garbage-collection-messages nil)
(setq read-process-output-max (* 8 1024 1024)) ;; 8MB

;; 起動後の復帰処理
(add-hook 'after-init-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024))
            (setq file-name-handler-alist my-saved-file-name-handler-alist)
            (message "Emacs init time: %s" (emacs-init-time))))

;; ============================================================
;; Native Compilation 設定 (Emacs 28+)
;; ============================================================
(when (featurep 'native-compile)
  (setq native-comp-async-report-warnings-errors 'silent)
  (setq native-compile-prune-cache t)) ;; キャッシュの定期掃除

;; ============================================================
;; 起動時の表示抑制
;; ============================================================
(setq inhibit-startup-screen t)
(setq inhibit-startup-message t)
(setq inhibit-startup-buffer-menu t)
(setq inhibit-default-init t)
(setq initial-scratch-message nil)
(setq initial-major-mode 'fundamental-mode)
(setq inhibit-startup-echo-area-message "mck") ;;"your-login-name"

;; ============================================================
;; フレーム設定（GUI構築前のチラつき防止）
;; ============================================================
;; フレームサイズのリサイズを抑制（重複を削除しました）
(setq frame-inhibit-implied-resize t)

;; 基本フレーム設定
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
  (setq ns-use-fullscreen-animation nil))

;; フルスクリーン設定
;; push はリストの先頭に追加されるため、後勝ちになります。
(push '(fullscreen . maximized) default-frame-alist)

;; ============================================================
;; その他
;; ============================================================
;; X resources無視
(advice-add 'x-apply-session-resources :override 'ignore)
;; マウスのダイアログ無効化
(setq use-dialog-box nil)
(setq use-file-dialog nil)

(provide 'early-init)
;;; early-init.el ends here
