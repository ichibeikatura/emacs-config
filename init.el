;; -*- lexical-binding: t; -*-
;;; Native Compilation
(with-eval-after-load 'comp
  (setq native-comp-async-jobs-number 12
        native-comp-speed 2))
(setq byte-compile-warnings '(not obsolete))
;;; Elpaca ブートストラップ
(defvar elpaca-installer-version 0.11)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

(elpaca elpaca-use-package
  (elpaca-use-package-mode))
;(elpaca-wait)

;;; Emacs 基本設定 & グローバルキーバインド

(use-package transient
  :ensure t
  :after no-littering  ; markdown-mode は外す
  :bind
  ("C-c t" . my/outline-menu)
  :config
  (require 'outline)
  (setq transient-history-file (no-littering-expand-var-file-name "transient/history.el"))
  (transient-define-prefix my/outline-menu ()
    "Custom Menu"
    [["表示と開閉"
      ("b" "見出表示 (hide-body)"    outline-hide-body)
      ("a" "全て表示 (show-all)"     outline-show-all)
      ("e" "非表示 (hide-subl)"      (lambda () (interactive) (outline-hide-sublevels 1)))
      ("o" "子ノード開閉トグル"      outline-toggle-children)
      ("m" "プレビュー切り替え"      markdown-toggle-markup-hiding)]
     ["範囲"
      ("s" "ナロー (subtree)"        markdown-narrow-to-subtree)
      ("w" "ワイド (全体)"           widen)]
     ["タブ"
      ("d" "Close"                   tab-bar-close-tab)
      ("n" "New"                     tab-bar-new-tab)]]))

(use-package emacs
  :custom
  ;; 現代的なマシンスペックに合わせてUndo制限を緩和
  (undo-limit 67108864)         ; 64MB
  (undo-strong-limit 100663296) ; 96MB
  (undo-outer-limit 1006632960) ; 960MB
;; バックアップ
  (backup-by-copying t)
  (version-control t)
  (kept-old-versions 3)
  (kept-new-versions 5)
  (delete-old-versions t)
  :init
  ;; 基本設定
  (prefer-coding-system 'utf-8-hfs)
  (set-file-name-coding-system 'utf-8-hfs)
  (setenv "LANG" "ja_JP.UTF-8")
  (set-language-environment 'Japanese)
  (setq use-short-answers t
        create-lockfiles nil
        read-file-name-completion-ignore-case t
        enable-recursive-minibuffers t
        read-extended-command-predicate #'command-completion-default-include-p
        kill-ring-max 200)
  (setq auth-sources `(,(expand-file-name "~/.authinfo")))
  ;; Minibuffer Prompt
  (setq minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))
  (setq split-width-threshold nil)
  ;; サーバー起動
  (add-hook 'emacs-startup-hook
          (lambda ()
            (require 'server)
            (unless (server-running-p) (server-start))))
  (add-to-list 'auto-mode-alist '("\\.txt\\'" . markdown-mode))
  ;; ネットワーク経由のホスト解決を無効化
  (setq ffap-machine-p-known 'reject)
  :bind
   ;; タブ操作
   ("M-{" . tab-previous)
   ("M-}" . tab-next)

   ;; バッファ操作
   ("C-t" . switch-to-next-buffer)
   ("C-M-t" . switch-to-prev-buffer)
   ("C-x C-b" . bs-show)
   ("C-c C-b" . ibuffer)
   ("C-c C-o" . revert-buffer-quick)
   
   ;; 検索・編集・移動
   ("C-M-s" . isearch-forward)
   ("M-=" . count-words-region)
   ("C-h" . backward-delete-char)
   ("C-c o" . browse-url-at-point)
   ("C-c C-f" . consult-fd)
   ("C-c C-j" . open-junk-file)   

   ;; 補完・展開
   ("C-]" . hippie-expand)
   ("C-\\" . dabbrev-expand))

;;; load-path
;; ~/.emacs.d/site-lisp 定義
(defvar my-site-lisp-dir (locate-user-emacs-file "site-lisp"))

;; ディレクトリが存在すれば、その直下のサブディレクトリを全部 load-path に追加
(when (file-directory-p my-site-lisp-dir)
  (add-to-list 'load-path my-site-lisp-dir) ;; site-lisp自体も追加
  (let ((default-directory my-site-lisp-dir))
    (normal-top-level-add-subdirs-to-load-path)))

;;; macOS 固有設定
(when (eq system-type 'darwin)
  (setq mac-option-modifier 'super
        ns-command-modifier 'meta)
  (setq ns-use-proxy-icon nil)
  (setenv "PATH" (concat "/usr/local/bin:/opt/homebrew/bin:" (getenv "PATH")))
  (add-to-list 'exec-path "/usr/local/bin")
  (add-to-list 'exec-path "/opt/homebrew/bin"))

;;; 表示・UI
;;; ========================================l
(blink-cursor-mode -1)
;(display-battery-mode 1)
(global-hl-line-mode 1)
(transient-mark-mode 1)
(fringe-mode 0)
(set-display-table-slot standard-display-table 'wrap ?\ )
(setq truncate-lines nil
      truncate-partial-width-windows nil
      show-paren-delay 0)
(show-paren-mode 1)

;;; FFAP

;(ffap-bindings)
(global-set-key [remap find-file] 'find-file-at-point)
(autoload 'find-file-at-point "ffap" nil t)

 
;;; 配列 (Dvorak)

(setq skk-henkan-show-candidates-keys
      '(?a ?o ?e ?u ?i ?d ?h ?t ?n ?s ?-))

(defconst my-dvorak-translation-table
  "\C-@\C-a\C-b\C-c\C-d\C-e\C-f\C-g\C-h\011\012\C-k\C-l\C-m\C-n\C-o\C-p\C-q\C-r\C-s\C-t\C-u\C-v\C-w\C-x\C-y\C-z\C-[\C-\\\C-]\C-^\C-_\040!_#$%&-()*+w\\vz0123456789SsW=VZ@AXJE>UIDCHTNMBRL\"POYGK<QF:[/]^|`axje.uidchtnmbrl'poygk,qf;{?}~\C-?"
  "Pre-calculated Dvorak translation table.")

(defun dvorak ()
  "Switch to Dvorak layout instantly."
  (interactive)
  (setq keyboard-translate-table my-dvorak-translation-table)
  (message "Input: Dvorak"))

(defun qwerty ()
  "Switch to Qwerty layout instantly."
  (interactive)
  (setq keyboard-translate-table nil)
  (message "Input: Qwerty"))

(dvorak)

;;; 文字コード・濁点分離対策

(defun my/normalize-nfc-buffer ()
  "バッファ全体をNFC正規化"
  (interactive)
  (let ((modified (buffer-modified-p))
        (p (point)))
    (ucs-normalize-NFC-region (point-min) (point-max))
    (goto-char (min p (point-max)))
    (set-buffer-modified-p modified)))

;; 侵入経路1: ファイル読み込み時
(add-hook 'find-file-hook #'my/normalize-nfc-buffer)

;; 侵入経路2: 保存前（念のため）
(add-hook 'before-save-hook #'my/normalize-nfc-buffer)

;; 侵入経路3: クリップボード経由
(defun my/normalize-nfc-yank (orig-fun &rest args)
  (let ((result (apply orig-fun args)))
    (ucs-normalize-NFC-region (region-beginning) (region-end))
    result))

(advice-add 'yank :around #'my/normalize-nfc-yank)

(use-package no-littering
  :ensure t
  :config
  ;; オートセーブとバックアップの場所を固定
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t)))
  (setq backup-directory-alist
        `((".*" . ,(no-littering-expand-var-file-name "backup/"))))
  (setq version-control t)     ;; バージョン番号をつける
  (setq kept-new-versions 5)   ;; 最新5世代残す
  (setq kept-old-versions 0)   ;; 最古は残さない
  (setq delete-old-versions t) ;; 古いものは勝手に消す
  )

(use-package tab-bar
  :ensure nil
  :custom
  (tab-bar-new-tab-choice "*scratch*"))

(use-package vim-tab-bar
  :ensure t
  :config
  (vim-tab-bar-mode 1))

;;; Nerd Icons
(use-package nerd-icons
  :ensure t)

;;; 補完エコシステム (Vertico, Consult, etc.)

(use-package vertico
  :ensure t
  :custom
  (vertico-count 18)
  (vertico-resize nil)
  (vertico-cycle t)
  (vertico-sort-function #'vertico-sort-history-alpha)
  :init
  (vertico-mode 1)
  :config
  (require 'vertico-directory)
  (setq completion-category-overrides
	'((file (styles basic partial-completion orderless))))
  (keymap-set vertico-map "RET" #'vertico-directory-enter)
  (keymap-set vertico-map "DEL" #'vertico-directory-delete-char))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic)))

(use-package marginalia
  :ensure t
  :custom
  (marginalia-align 'right)
  (marginalia-align-offset -2)
  :init
  (marginalia-mode 1))


(use-package consult
  :ensure t
  :bind
  (("C-s" . consult-line)
   ("C-M-l" . consult-outline)
   ("C-;" . consult-history)
   ;; 統合されたキーバインド
   ("C-M-y" . consult-yank-pop)
   ("C-'" . consult-buffer)
   ("M-g M-g" . consult-goto-line)
   ("C-c C-s" . consult-ripgrep)
   ("C-x C-y" . consult-recent-file))
  :custom
  (consult-preview-raw-size 1024000)
  (consult-async-refresh-delay 0.1)
  (consult-narrow-key "?"))

(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :hook
  (marginalia-mode . nerd-icons-completion-marginalia-setup)
  :init
  (nerd-icons-completion-mode 1))

;;; テーマ
(use-package doric-themes
  :ensure t
  :demand t
  :bind
  (("C-c C-r" . doric-themes-load-random)
   ("C-c C-t" . doric-themes-select))
  :config
  (doric-themes-select 'doric-cherry))

;;; Which Key
(use-package which-key
  :ensure t
  :custom
  (which-key-max-description-length 40)
  (which-key-use-C-h-commands t)
  :init
  (which-key-mode 1))

;;; Midnight（古いバッファ自動削除）
(use-package midnight
  :init
  (midnight-mode 1))

;;; ユーティリティ
(use-package uptimes
  :ensure t
  :config
  (setq uptimes-database-file (no-littering-expand-var-file-name "uptimes.el")
  ))

(use-package kreplace
  :ensure nil
  :no-require t
  :bind ("C-c C-y" . kreplace)
  :init
  (defconst kreplace-kyujitai "亞惡壓圍醫爲壹飮隱鬱營榮衞驛圓艷鹽奧應歐毆穩櫻假價畫屆會壞懷繪擴覺學嶽樂殼勸卷歡罐觀關巖顏凾陷歸氣龜僞戲犧舊據擧峽挾狹曉區驅勳徑惠溪經繼莖螢輕鷄藝缺儉劍圈檢權獻縣險顯驗嚴效據廣恆鑛號國濟碎齋册劑雜參蠶棧慘讚贊殘齒兒辭濕實舍寫釋壽收龝從澁獸縱肅處敍奬將燒稱證乘剩壤孃條淨疊穰讓釀觸寢愼晉眞盡繩圖粹醉穗隨髓數樞聲靜齊竊攝專戰淺濳纖踐錢禪壯雙搜插爭總聰莊裝騷臟藏屬續墮體對帶滯臺擇澤單擔膽團彈斷遲癡晝蟲鑄廳聽鎭遞鐵轉點傳兔黨當盜燈稻鬪獨讀貳惱腦廢拜賣麥發髮拔蠻濱拂佛變竝篦邊辨餠舖寶豐冐沒萬滿默來亂彌藥譯豫餘與譽搖樣謠覽兩獵壘勵禮靈齡戀爐勞樓瀧祿蘆灣祕囑劵敕豎廚禰")
 
  (defconst kreplace-shinjitai "亜悪圧囲医為壱飲隠欝営栄衛駅円艶塩奥応欧殴穏桜仮価画届会壊懐絵拡覚学岳楽殻勧巻歓缶観関巌顔函陥帰気亀偽戯犠旧拠挙峡挟狭暁区駆勲径恵渓経継茎蛍軽鶏芸欠倹剣圏検権献県険顕験厳効拠広恒鉱号国済砕斎冊剤雑参蚕桟惨讃賛残歯児辞湿実舎写釈寿収穐従渋獣縦粛処叙奨将焼称証乗剰壌嬢条浄畳穣譲醸触寝慎晋真尽縄図粋酔穂随髄数枢声静斉窃摂専戦浅潜繊践銭禅壮双捜挿争総聡荘装騒臓蔵属続堕体対帯滞台択沢単担胆団弾断遅痴昼虫鋳庁聴鎮逓鉄転点伝兎党当盗灯稲闘独読弐悩脳廃拝売麦発髪抜蛮浜払仏変並箆辺弁餅舗宝豊冒没万満黙来乱弥薬訳予余与誉揺様謡覧両猟塁励礼霊齢恋炉労楼滝禄芦湾秘嘱券勅竪厨祢")
  (defun kreplace ()
    "クリップボードの文字列から改行・空白を取り、旧字体を新字体に変換して挿入"
    (interactive)
    (let* ((str (gui-get-selection 'CLIPBOARD))
           (clean-str (replace-regexp-in-string "[ \t\n\r　]+" "" (or str "")))
           ;; ▼ 修正箇所: seq-map + apply string
           (result-str (apply #'string
                              (seq-map (lambda (c)
                                         (if-let* ((pos (seq-position kreplace-kyujitai c)))
                                             (aref kreplace-shinjitai pos)
                                           c))
                                       clean-str))))
      (insert result-str))))

(use-package imenu-list
  :ensure t
  :bind ("C-c n" . imenu-list-smart-toggle)
  :custom
  (imenu-list-position 'left)
  (imenu-list-size 40)
  (imenu-list-auto-resize nil))

;(use-package diredfl
;  :ensure t
;  :hook (dired-mode . diredfl-mode))

;;; Markdown
(use-package markdown-mode
  :ensure t
  :hook
  (markdown-mode . markdown-toggle-markup-hiding)
  :bind (:map markdown-mode-map
         ("C-c I" . my/markdown-paste-image-macos)
         ("C-c C-i" . markdown-toggle-inline-images))
  :custom
  (markdown-fontify-code-blocks-natively t)
  (markdown-header-scaling t)
  (markdown-indent-on-enter 'indent-and-new-item)
  :config
  (setq markdown-mode-map (make-sparse-keymap))

  ;; --- macOS用 画像貼り付け機能 ---
(defun my/markdown-paste-image-macos ()
  (interactive)
  (unless (eq system-type 'darwin)
    (user-error "This function is for macOS only"))
  (unless (executable-find "pngpaste")
    (user-error "pngpaste is not installed"))
  
  (let* ((img-name (format-time-string "%Y%m%d_%H%M%S.png"))
         (img-dir (expand-file-name "images/" default-directory)) ;; buffer-file-name依存を減らす
         (img-path (expand-file-name img-name img-dir))
         (rel-path (file-relative-name img-path default-directory)))
    
    (unless (file-exists-p img-dir)
      (make-directory img-dir t))
    
    ;; shell-command ではなく call-process を使用
    (if (zerop (call-process "pngpaste" nil nil nil img-path))
        (progn
          (insert (format "![](%s)" rel-path))
          ;; カーソル位置調整などが不要ならこれだけでOK
          (message "Saved: %s" rel-path))
      (user-error "pngpaste failed; ensure an image is in the clipboard"))))

  ;; --- 画像表示時の自動縮小 (40%) ---
  (defun my/create-image-with-width (orig file &optional type data-p &rest props)
    (let ((type (or type (image-type file data-p))))
      (if (and (derived-mode-p 'markdown-mode)
               (eq type 'png))
          (apply orig file type data-p (plist-put props :scale 0.4))
        (apply orig file type data-p props))))
  (advice-add 'create-image :around #'my/create-image-with-width))

;;; バッファ名の一意化
(use-package uniquify
  :custom
(setq uniquify-buffer-name-style 'post-forward-angle-brackets
      uniquify-ignore-buffers-re "^\\*"))

;;; Super Save（自動保存強化）
(use-package super-save
  :ensure t
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-idle-duration 1)
  (save-silently t)
  :config
  (add-to-list 'super-save-triggers 'switch-window)
  (super-save-mode 1))

;;; So Long（長い行のパフォーマンス対策）
(use-package so-long
  :init
  (global-so-long-mode 1))

;;; 履歴・状態の永続化
(use-package savehist
  :custom
  (savehist-additional-variables '(kill-ring))
  :init
  (savehist-mode 1))

(use-package saveplace
  :init
  (save-place-mode 1))

;;; Auto Revert（外部変更の自動反映）
(use-package autorevert
  :custom
  (auto-revert-interval 1)
  :init
  (global-auto-revert-mode 1))

;;; 検索ツール (Deadgrep)
(use-package deadgrep
  :ensure t
  :commands deadgrep
  :bind ("C-c S" . deadgrep)
  :custom
  (deadgrep-extra-arguments '("--no-ignore-vcs")))

;;; Disable Mouse
(use-package disable-mouse
  :ensure t
  :init
  (global-disable-mouse-mode 1))

;;; Recentf
(use-package recentf
  :after no-littering
  :custom
  (recentf-max-saved-items 2000)
  (recentf-auto-cleanup 'never)
  (recentf-exclude '("\\.recentf"
                     "^/tmp/"
                     "/\\.git/"))
  :config
  (recentf-mode 1)
  (run-with-idle-timer 600 t #'recentf-cleanup))

(use-package recentf-ext
  :ensure t
  :after recentf)

;;; Lookup
(use-package lookup
  :defer t
  :commands (lookup lookup-region lookup-pattern lookup-word lookup-select-search-pattern)
  :bind
  (("C-x l" . lookup)
   ("C-x '" . lookup-word)
   ("C-x L" . lookup-select-search-pattern))
  :custom
  (lookup-enable-splash nil)
  (lookup-max-hits 0)
  (lookup-max-text 0)
  (lookup-window-height 0.16)
  (lookup-search-agents
   '((ndebs "/usr/local/share/dict/hyogen/")
     (ndebs "/usr/local/share/dict/saiji/")
     (ndebs "/usr/local/share/dict/KENCHU/")
     (ndebs "/usr/local/share/dict/KOJIEN5/")
     (ndebs "/usr/local/share/dict/syogakkan/")
     (ndebs "/usr/local/share/dict/heibon/")
     (ndebs "/usr/local/share/dict/wordnet-jp/")
     (ndebs "/usr/local/share/dict/ldae/")
     (ndebs "/usr/local/share/dict/nihonshi/")
     (ndebs "/usr/local/share/dict/skp/")
     (ndebs "/usr/local/share/dict/chimei/")
     (ndebs "/usr/local/share/dict/mypedia/")
     (ndebs "/usr/local/share/dict/jinmei/")))
  :config
  (setq lookup-open-function 'lookup-full-screen)
  ;;  lookup 1.4+ から lookup-foreach が消えた対策
  (unless (fboundp 'lookup-foreach)
    (defalias 'lookup-foreach #'mapc)))
  

;;; Prescient
(use-package prescient
  :ensure t
  :custom
  (prescient-aggressive-file-save t)
  :config
  (prescient-persist-mode 1))

(use-package vertico-prescient
  :ensure t
  :after vertico
  :custom
  (vertico-prescient-enable-filtering nil)
  :init
  (vertico-prescient-mode 1))

;;; Dirvish
(use-package dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-default-layout '(0 0.4 0.6))
  (dirvish-use-header-line 'global)
  (dirvish-highlight-current-line t)
  (dirvish-use-mode-line 'global)
  (dirvish-mode-line-format
   '(:left (sort symlink) :right (omit yank index)))
(dirvish-attributes
   '(nerd-icons subtree-state vc-state file-size file-time file-modes git-msg collapse))
  (dirvish-subtree-state-style 'nerd)
  (dirvish-path-separators '("  ~" "  " "/"))
  (insert-directory-program "gls")
  (dired-listing-switches
   "-l --almost-all --human-readable --group-directories-first --no-group")
  (delete-by-moving-to-trash t)
  (dirvish-preview-disabled-exts '("iso" "bin" "exe" "gpg" "mp4" "mkv" "avi"))
  :config
(setq dirvish-quick-access-entries
      `(("h" ,(expand-file-name "~/")           "/")
        ("d" ,(expand-file-name "~/Downloads/") "Downloads")
        ("t" ,(expand-file-name "~/.Trash/")    "Trash")
        ("c" ,user-emacs-directory              ".emacs.d")))
  :bind
  (:map dirvish-mode-map
        ("a" . dirvish-quick-access)
        ("f" . dirvish-file-info-menu)
        ("y" . dirvish-yank-menu)
        ("s" . dirvish-quicksort)
        ("TAB" . dirvish-subtree-toggle)
	("<backspace>" . dired-up-directory)))


;;; BM（可視ブックマーク）
(use-package bm
  :ensure t
  :bind
  (("C-M-m" . bm-toggle)
   ("C-M-p" . bm-previous)
   ("C-M-n" . bm-next)
   ("C-M-a" . bm-show-all)
   ("C-M-o" . bm-find-files-in-repository))
  :custom
  (bm-restore-repository-on-load t)
  (bm-cycle-all-buffers t)
  (bm-buffer-persistence t)
  :hook
  (after-init . bm-repository-load)
  (kill-buffer . bm-buffer-save)
  (after-save . bm-buffer-save)
  (find-file . bm-buffer-restore)
  (after-revert . bm-buffer-restore)
  (vc-before-checkin . bm-buffer-save)
  (kill-emacs . (lambda ()
                  (ignore-errors (bm-repository-save)))))

;;; Magit & Forge
(use-package magit
  :ensure t
  :bind
  ("C-x g" . magit-status)
  :custom
  (magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1)
  (magit-diff-paint-whitespace nil)
  (magit-diff-refine-hunk t))

(use-package git-commit
  :after magit
  :custom
  (git-commit-fill-column 999)
  (git-commit-summary-max-length 999)
  (git-commit-style-convention-checks nil))

(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

;;; 日本語入力 & 変換 (DDSKK / Dabbrev)
(with-eval-after-load 'dabbrev
  (defvar dabbrev-abbrev-char-regexp)
  (defun my/dabbrev-japanese-regexp ()
    "カーソル直前の文字種に応じた正規表現を返す。"
    (when (not (bobp))
      (let ((c (char-category-set (char-before))))
        (cond
         ((aref c ?a) "[-_A-Za-z0-9]")
         ((aref c ?K) "\\cK")
         ((aref c ?A) "\\cA")
         ((aref c ?H) "\\cH")
         ((aref c ?C) "\\cC")
         ((aref c ?j) "\\cj")
         ((aref c ?k) "\\ck")
         ((aref c ?r) "\\cr")
         (t nil)))))
  (define-advice dabbrev-expand (:around (orig-fn &rest args) japanese-support)
    "日本語文字種に応じて `dabbrev-abbrev-char-regexp' を動的に変更。"
    (let ((dabbrev-abbrev-char-regexp
           (or (my/dabbrev-japanese-regexp)
               dabbrev-abbrev-char-regexp)))
      (apply orig-fn args))))
(setq hippie-expand-try-functions-list
      '(try-expand-dabbrev
        try-expand-dabbrev-all-buffers
        try-complete-file-name-partially
        try-complete-file-name))

(use-package ccc
  :ensure (:version (lambda (_) "1.43")))

(use-package skk-lookup
  :ensure nil
  :defer t
  :config
  (setq skk-lookup-search-agents
        (cl-remove-if (lambda (x) (memq (car x) '(ndkks ndcookie ndnmz)))
                     lookup-search-agents))


  ;; 辞書設定:マクロ定義: 設定記述を簡単にするためのローカル関数
  (let ((add-opt (lambda (dic-name regexp split)
                   (add-to-list 'skk-lookup-option-alist
                                (list dic-name
                                      'exact   ;; [0] 送りなし時メソッド
                                      'exact   ;; [1] 送りあり時メソッド
                                      'exact   ;; [2] 接頭辞・その他
                                      t        ;; [3] 検索対象フラグ
                                      regexp   ;; [4] 抽出正規表現 (重要: ペアで指定)
                                      split    ;; [5] 分割文字
                                      nil))))) ;; [6] 整形正規表現

    ;; 1. 【 】の中身を抽出するタイプ (広辞苑など)
    (dolist (dic-name '("kojien" "jirin21" "hot01" "skpkogo2" "skpkoku2" "skpkoji2" "hyogen"))
      (funcall add-opt dic-name '("【\\([^】]+\\)】" . 1) "・"))

    ;; 2. 行頭の【 】抽出・分割なし (SKP漢語)
    (funcall add-opt "skpknw2" '("^【\\([^】]+\\)】" . 1) nil)

    ;; 3. （ ）の中身抽出・／分割 (マイペディア)
    (funcall add-opt "mypaedia" '("（\\([^）]+\\)）" . 1) "／")

    ;; 4. スペースの後ろ抽出 (研究社中辞典)
    (funcall add-opt "chujiten" '("\\s-+\\(.+\\)$" . 1) nil)

    ;; 5. 【 】の前方抽出 (日本史辞典)
    (funcall add-opt "nihonshi" '("^\\([^【]+\\)【" . 1) nil)

    ;; 6. そのまま抽出 (新選国語、百科事典)
    (dolist (dic-name '("ssn" "ency" "chimei" "jinmei"))
      (funcall add-opt dic-name nil nil))))

(use-package ddskk
  :ensure t
  :demand t
  :init
  (setq skk-user-directory (expand-file-name "~/.skk.d"))
  :bind
  ("M-o" . skk-mode)
  :preface
  (defun skk-open-server-decoding-utf-8 ()
    "辞書サーバと接続する。サーバープロセスを返す。 decoding coding-system が euc ではなく utf8 となる。"
    (unless (skk-server-live-p)
      (setq skkserv-process (skk-open-server-1))
      (when (skk-server-live-p)
        (let ((code (cdr (assoc "euc" skk-coding-system-alist))))
          (set-process-coding-system skkserv-process 'utf-8 code))))
    skkserv-process)
  (advice-add 'skk-open-server :override 'skk-open-server-decoding-utf-8)
  :custom
  (skk-jisyo-code 'utf-8)
  (skk-server-host "localhost")
  (skk-server-portnum 1178)
  (skk-server-prog "yaskk.sh")
  (skk-server-report-response t)
  (skk-share-private-jisyo t)
  (skk-delete-implies-kakutei nil)
  (skk-henkan-number-to-display-candidates 10)
  (skk-henkan-strict-okuri-precedence t)
  (skk-check-okurigana-on-touroku t)
  (skk-use-numeric-conversion t)
  (skk-dcomp-activate t)
  (skk-use-look t)
  (skk-auto-insert-paren t)
  (skk-use-color-cursor t)
  (skk-inhibit-ja-dic-search t)
  (skk-latin-mode-string "[_A]")
  (skk-hiragana-mode-string "[あ]")
  (skk-katakana-mode-string "[ア]")
  (skk-jisx0208-latin-mode-string "[Ａ]")
  (skk-jisx0201-mode-string "[_ｱ]")
  (skk-abbrev-mode-string "[aA]")
  (skk-indicator-use-cursor-color t)
  (skk-status-indicator 'left)
  :config
  ;; インジケータ設定
  (define-advice skk-make-indicator-alist (:filter-return (alist) my-indicator)
    (dolist (elem '((abbrev " [aA]" . "--[aA]:")
                    (latin " [_A]" . "--[_A]:")
                    (default " [--]" . "--[--]:")))
      (setq alist (cons elem (assq-delete-all (car elem) alist))))
    alist)
  (require 'lookup)
  (require 'skk-lookup)
  (require 'skk-bayesian)
  (setq skk-search-prog-list
        '((skk-search-jisyo-file skk-jisyo 0 t)
          (skk-search-kakutei-jisyo-file skk-kakutei-jisyo 10000 t)
          (skk-search-jisyo-file skk-initial-search-jisyo 10000 t)
          (skk-search-server skk-aux-large-jisyo 10000)
          (skk-okuri-search)
	  (skk-lookup-search)
          ))
  )

(use-package ddskk-posframe
  :ensure t
  :after skk
  :config
  (ddskk-posframe-mode 1))

;;; Doom Modeline
(use-package doom-modeline
  :ensure t
  :custom
  (doom-modeline-buffer-file-name-style 'truncate-with-project)
  (doom-modeline-support-imenu t)
  (doom-modeline-height 24)
  (doom-modeline-icon t)
  (doom-modeline-major-mode-icon t)
  (doom-modeline-major-mode-color-icon nil)
  (doom-modeline-minor-modes t)
  (doom-modeline-bar-width 5)
  :config
  (doom-modeline-mode 1)
  (doom-modeline-def-segment my-buffer-size
    "Display current buffer size"
    (format "%s" (buffer-size)))

  (doom-modeline-def-segment my-line-stats
    "現在の行番号と総行数を表示。"
    (format "%d/%d"
            (line-number-at-pos)
            (line-number-at-pos (point-max))))

  (doom-modeline-def-modeline 'main
    '(buffer-encoding bar workspace-name buffer-info " ¦¦" vcs)
    '(bar "✎" my-buffer-size " ¦ ☯" my-line-stats process " " hud " " major-mode))

  (doom-modeline-def-modeline 'list
    '(" ☯ imenu-list " bar)
    '("Line_" my-line-stats)))

(use-package dmacro
  :ensure t
  :bind ("C-M-'" . dmacro-exec))


;;; フォント設定
(defvar my-font-options '(("Mplus 1 code" . "Mplus 1 code") ("PlemolJP" . "PlemolJP Console NF")))
(defvar my-current-font-name "Mplus 1 code")
(defvar my-current-font-size 14)

(defun my-set-font (name size &optional frame)
  "Set font to NAME with SIZE. Updates global vars if FRAME is nil."
  (when (member name (font-family-list))
    (unless frame (setq my-current-font-name name my-current-font-size size))
    (set-face-attribute 'default frame :font (format "%s-%d" name size))))

(defun my/change-font () (interactive)
  (let ((choice (completing-read "Font: " (mapcar #'car my-font-options))))
    (my-set-font (cdr (assoc choice my-font-options)) (read-number "Size: " my-current-font-size))))

(defun my/increase-font-size () (interactive) (my-set-font my-current-font-name (1+ my-current-font-size)))
(defun my/decrease-font-size () (interactive) (my-set-font my-current-font-name (max 8 (1- my-current-font-size))))

(add-hook 'after-make-frame-functions (lambda (f) (my-set-font my-current-font-name my-current-font-size f)))

;;; 便利ツール & 自作関数

;;  nhg-minor-mode (日本語執筆支援)
(use-package nhg-minor-mode
  :ensure (nhg-minor-mode
           :url "https://github.com/ichibeikatura/nhg-minor-mode")
  :hook ((text-mode markdown-mode) . nhg-minor-mode))

(use-package proofreader
  :ensure (proofreader
           :url "https://github.com/ichibeikatura/proofreader.el")
  :bind (("C-c p s" . proofreader-send-buffer)
         ("C-c p i" . proofreader-apply-interactive)
         ("C-c p r" . proofreader-send-region)
         ("C-c p o" . proofreader-open-json)
         ("C-c p a" . proofreader-apply)))

;;  year-convert (西暦・和暦変換)
(use-package year-convert
  :ensure (year-convert
           :url "https://github.com/ichibeikatura/year-convert")
  :bind ("C-M-=" . year-convert-at-point))


(defun my/epub-convert ()
  "現在のバッファ内容をPythonスクリプトに渡してEPUB化し、プレビューする。"
  (interactive)
  ;; 保存していない変更があれば保存
  (when (buffer-modified-p)
    (save-buffer))
  (let ((script-path (expand-file-name "~/Documents/github/convert_epub/convert_epub.py")))
    (message "Generating EPUB...")
    (shell-command-on-region 
     (point-min) (point-max) 
     script-path)
    (message "EPUB generation sent.")))
(global-set-key (kbd "C-q") #'my/epub-convert)

;; 個人設定
(defun my/insert-diary-entry ()
  "日記エントリを挿入する。"
  (interactive)
  (let* ((input (read-string "日付 (YYYYMMDD): "))
         (date (format "%s年%s月%s日"
                       (substring input 0 4)
                       (substring input 4 6)
                       (substring input 6 8)))
         (source (read-string "出典: "))
         (author (if (string-match "^\\([^ 　]+\\)" source)
                     (match-string 1 source)
                   "")))
    (insert (format "%s | %s\n" date author))
    (let ((body-pos (point)))
      (insert (format "\n出典:%s\n\n----\n" source))
      (goto-char body-pos))))
(global-set-key (kbd "C-c d") #'my/insert-diary-entry)

;;;メモ書き用
(defvar my/junk-file-directory (expand-file-name "~/My Drive/memo/")
  "Junkファイルの保存ディレクトリ")
(defun open-junk-file ()
  (interactive)
  (let* ((file (expand-file-name
                (format-time-string "%Y_%m_%d_%H_%M_%S.txt" (current-time))
                my/junk-file-directory))
         (dir (file-name-directory file)))
    (find-file file)
    (insert (format-time-string "%Y-%m-%d %H:%M\n" (current-time)))
    (insert "#title: ")))

;; ネイティブコンパイル
(defun my/native-comp-packages ()
  "個人設定ファイルとパッケージをネイティブコンパイルする。"
  (interactive)
  (let ((files (list (locate-user-emacs-file "init.el")
                     (locate-user-emacs-file "early-init.el")))
        (dirs (list (locate-user-emacs-file "elpaca/builds/")
                    (locate-user-emacs-file "site-lisp/"))))
    (dolist (file files)
      (when (file-exists-p file)
        (native-compile-async file)))
    (dolist (dir dirs)
      (when (file-directory-p dir)
        (native-compile-async dir 'recursively)))))

;; init.el ends here
