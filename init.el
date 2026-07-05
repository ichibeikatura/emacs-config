;; -*- lexical-binding: t; -*-

;;; Native Compilation
;; Emacs 30+ では native-comp-async-jobs-number が comp-run.el 所属になり、
;; with-eval-after-load 'comp では効かない経路があるため直接 setq する
(setq native-comp-async-jobs-number 12)
(setq byte-compile-warnings '(not obsolete))

;;; Elpaca ブートストラップ
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
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
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

(elpaca elpaca-use-package
  (elpaca-use-package-mode))
;; ここで待たないと以降の use-package の :ensure が package.el に落ちる
(elpaca-wait)

;; パス系の設定を他の全パッケージより先に確定させるため同期ロードする
(use-package no-littering
  :ensure t
  :demand t
  :config
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t)))
  (setq backup-directory-alist
        `((".*" . ,(no-littering-expand-var-file-name "backup/"))))
  ;; version-control / delete-old-versions は emacs ブロックの :custom で設定済み
  (setq kept-new-versions 5)
  (setq kept-old-versions 3))
(elpaca-wait)

;;; Emacs 基本設定 & グローバルキーバインド
(use-package emacs
  :custom
  (undo-limit 67108864)
  (undo-strong-limit 100663296)
  (undo-outer-limit 1006632960)
  (backup-by-copying t)
  (version-control t)
  (delete-old-versions t)
  :init
  ;; set-language-environment はコーディング優先度をリセットするため先に呼ぶ
  (set-language-environment 'Japanese)
  (prefer-coding-system 'utf-8)
  (set-file-name-coding-system 'utf-8)
  (setenv "LANG" "ja_JP.UTF-8")
  (setq use-short-answers t
        create-lockfiles nil
        enable-recursive-minibuffers t
        read-extended-command-predicate #'command-completion-default-include-p
        kill-ring-max 200)
  (setq auth-sources `(,(expand-file-name "~/.authinfo.gpg")))
  (setq minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))
  ;; cursor-intangible は cursor-intangible-mode が有効なバッファでのみ効く
  (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)
  (setq split-width-threshold nil)
  (setq auto-window-vscroll nil)
  (setq fast-but-imprecise-scrolling t)
  (add-to-list 'auto-mode-alist '("\\.txt\\'" . markdown-mode))
  (setq ffap-machine-p-known 'reject)
  :bind
   ("M-{" . tab-previous)
   ("M-}" . tab-next)
   ("C-t" . switch-to-next-buffer)
   ("C-M-t" . switch-to-prev-buffer)
   ("C-x C-b" . bs-show)
   ("C-c C-b" . ibuffer)
   ("C-c C-o" . revert-buffer-quick)
   ([remap find-file] . find-file-at-point)
   ("C-M-s" . isearch-forward)
   ("M-=" . count-words-region)
   ("C-h" . backward-delete-char)
   ("C-c o" . browse-url-at-point)
   ("C-c C-f" . consult-fd)
   ("C-c C-j" . open-junk-file)
   ("C-]" . hippie-expand)
   ("C-\\" . dabbrev-expand)
   ("C-q" . my/epub-convert)
   ("C-c d" . my/insert-diary-entry)
   )

;;; load-path
(defvar my-site-lisp-dir (locate-user-emacs-file "site-lisp"))
(when (file-directory-p my-site-lisp-dir)
  (add-to-list 'load-path my-site-lisp-dir)
  (let ((default-directory my-site-lisp-dir))
    (normal-top-level-add-subdirs-to-load-path)))

;;; macOS 固有設定
(when (eq system-type 'darwin)
  (setq ns-alternate-modifier 'super
        ns-command-modifier 'meta)
  (setq ns-use-proxy-icon nil)
  (setenv "PATH" (concat (expand-file-name "~/.bin") ":"
                           (expand-file-name "~/.local/bin") ":"
                           "/usr/local/bin:/opt/homebrew/bin:"
                           (getenv "PATH")))
  (add-to-list 'exec-path "/usr/local/bin")
  (add-to-list 'exec-path "/opt/homebrew/bin")
  (add-to-list 'exec-path (expand-file-name "~/.local/bin"))
  (add-to-list 'exec-path (expand-file-name "~/.bin"))
  )

(with-eval-after-load 'warnings
  (add-to-list 'warning-suppress-log-types '(files missing-lexbind-cookie))
  (add-to-list 'warning-suppress-types '(files missing-lexbind-cookie)))

;;; 表示・UI
(blink-cursor-mode -1)
(global-hl-line-mode 1)
(fringe-mode 0)
(set-display-table-slot standard-display-table 'wrap ?\ )
(setq truncate-partial-width-windows nil
      show-paren-delay 0)

;;; 配列 (Dvorak)
(setq skk-henkan-show-candidates-keys
      '(?a ?o ?e ?u ?i ?d ?h ?t ?n ?s ?-))

(defconst my-dvorak-translation-table
  "\C-@\C-a\C-b\C-c\C-d\C-e\C-f\C-g\C-h\011\012\C-k\C-l\C-m\C-n\C-o\C-p\C-q\C-r\C-s\C-t\C-u\C-v\C-w\C-x\C-y\C-z\C-[\C-\\\C-]\C-^\C-_\040!_#$%&-()*+w\\vz0123456789SsW=VZ@AXJE>UIDCHTNMBRL\"POYGK<QF:[/]^|`axje.uidchtnmbrl'poygk,qf;{?}~\C-?"
  "Pre-calculated Dvorak translation table.")

(defun dvorak ()
  "Switch to Dvorak layout instantly."
  (interactive)
  (setq keyboard-translate-table my-dvorak-translation-table))


(defun qwerty ()
  "Switch to Qwerty layout instantly."
  (interactive)
  (setq keyboard-translate-table nil)
  (message "Input: Qwerty"))

(dvorak)

;;; 文字コード・濁点分離対策

(defun my/normalize-nfc-buffer ()
  "バッファ全体をNFC正規化（modified状態は維持）。
read-only やユニバイト（バイナリ等）のバッファでは何もしない。
find-file-hook でエラーになるとファイルオープン自体を壊すため。"
  (interactive)
  (when (and (not buffer-read-only)
             enable-multibyte-characters)
    (let ((modified (buffer-modified-p))
          (p (point)))
      (ucs-normalize-NFC-region (point-min) (point-max))
      (goto-char (min p (point-max)))
      (set-buffer-modified-p modified))))
(add-hook 'find-file-hook #'my/normalize-nfc-buffer)
(add-hook 'before-save-hook #'my/normalize-nfc-buffer)

;; --- 保険: 1時間ごとに全バッファを正規化 ---
;; 謎の経路でNFDが混入しても定期的に畳む。実際に中身が変わったときだけ
;; modified になるので、super-save がディスクへ書き戻して修正が永続化される。
(defun my/normalize-nfc-buffer-if-changed ()
  "カレントバッファをNFC正規化。変化した場合のみ modified にする。"
  (let ((p (point)))
    (ucs-normalize-NFC-region (point-min) (point-max))
    (goto-char (min p (point-max)))))

(defun my/normalize-nfc-all-buffers ()
  "ファイルを訪問中で書き込み可能なマルチバイトバッファを正規化。"
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and buffer-file-name
                 (not buffer-read-only)
                 enable-multibyte-characters)
        (ignore-errors (my/normalize-nfc-buffer-if-changed))))))

(run-with-timer 3600 3600 #'my/normalize-nfc-all-buffers)

;;;フォント設定
(defvar my-font-alist '(("Mplus" . "Mplus 1 code") ("PlemolJP" . "PlemolJP Console NF")))
(defvar my-current-font-name "Mplus 1 code")
(defvar my-current-font-size 14)

(defun my--apply-font-to-new-frame (f)
  "新規グラフィカルフレーム F に現在のフォント設定を適用。"
  (when (display-graphic-p f)
    (set-face-attribute 'default f
                        :font (format "%s-%d" my-current-font-name my-current-font-size))))

(defun my-apply-font-config ()
  ;; 名前付き関数なので add-hook が重複登録を防ぐ（多重呼び出ししても安全）
  (add-hook 'after-make-frame-functions #'my--apply-font-to-new-frame))

;; yank系の集約: insert-for-yank は yank / yank-pop / マウス貼り付けが全て通る
;; 漏斗。挿入直後の領域を正規化するのでテキストプロパティを保持できる。
(define-advice insert-for-yank (:around (orig string) nfc-normalize)
  (let ((beg (point)))
    (funcall orig string)
    (ucs-normalize-NFC-region beg (point))))

;; 案2: クリップボード源流を正規化し、kill-ring へ入る時点でNFCにする。
(define-advice gui-get-selection (:filter-return (s) nfc-normalize)
  (if (stringp s) (ucs-normalize-NFC-string s) s))

(defun my--apply-font-now ()
  "現在のフレームにフォントを適用"
  (when (display-graphic-p)
    (set-face-attribute 'default nil
                        :font (format "%s-%d" my-current-font-name my-current-font-size))))

(defun my/change-font ()
  "対話的にフォントを変更"
  (interactive)
  (let ((choice (completing-read "Font: " (mapcar #'car my-font-alist))))
    (setq my-current-font-name (cdr (assoc choice my-font-alist))
          my-current-font-size (read-number "Size: " my-current-font-size))
    (my-apply-font-config)
    (my--apply-font-now)))

(defun my/resize-font (delta)
  (setq my-current-font-size (max 8 (+ my-current-font-size delta)))
  (my-apply-font-config)
  (my--apply-font-now))

(my-apply-font-config)
(my--apply-font-now)

(use-package transient
  :ensure t
  :bind
  ("C-c t" . my/outline-menu)
  :config
  (require 'outline)
  (setq transient-align-variable-pitch t)
  (transient-define-prefix my/outline-menu ()
    "Custom Menu"
    [["表示"
      ("h" "見出表示"    outline-hide-body)
      ("a" "全て表示"     outline-show-all)
      ("m" "装飾切替"      markdown-toggle-markup-hiding)]
     ["タブ"
      ("d" "Close"                   tab-bar-close-tab)
      ("n" "Newtab"                     tab-bar-new-tab)]
     ["校正"
      ("b" "バッファを校正"          proofreader-send-buffer)
      ("r" "選択部分を校正"          proofreader-send-region)
      ("i" "対話的に置き換え"        proofreader-apply-interactive)
      ("A" "一括置き換え"            proofreader-apply)
      ("o" "校正ファイルを開く"      proofreader-open-json)]
     ["zellij-send"
      ("z" "zellij-send"  zellij-send)]
     ]))

(use-package tab-bar
  :ensure nil
  :custom
  (tab-bar-new-tab-choice "*scratch*")
  (tab-bar-new-tab-to 'rightmost))

(use-package vim-tab-bar
  :ensure t
  :config
  (vim-tab-bar-mode 1))

;;; Nerd Icons
(use-package nerd-icons
  :ensure t)

;;; 補完エコシステム
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
   ("C-M-y" . consult-yank-pop)
   ("C-'" . consult-buffer)
   ("M-g M-g" . consult-goto-line)
   ("C-c C-s" . consult-ripgrep)
   ("C-x C-y" . consult-recent-file))
  :custom
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

;;; Which Key (Emacs 30+ built-in)
(use-package which-key
  :ensure nil
  :custom
  (which-key-max-description-length 40)
  (which-key-use-C-h-commands t)
  :init
  (which-key-mode 1))

;;; Midnight
(use-package midnight
  :init
  (midnight-mode 1))

;;; ユーティリティ
;; 保存先 uptimes-database は no-littering が var/ へ設定する
(use-package uptimes
  :ensure t)

(use-package kreplace
  :ensure nil
  :no-require t
  :bind ("C-c C-y" . kreplace)
  :init
  ;; 旧字体・異体字 → 新字体 変換テーブル
  ;; 各文字列の同一位置が対応ペアになる
;;; kreplace 旧字体→新字体 変換テーブル（統合版）
;; 旧字 381 / 新字 381（位置対応・旧字側重複なし・衝突なしを検証済み）

(defconst kreplace-kyujitai
  (concat
   ;; 原テーブル
   "亞惡壓圍醫爲壹飮隱鬱營榮衞驛圓艷鹽奧應歐毆穩櫻"
   "假價畫屆會壞懷繪擴覺學嶽樂殼勸卷歡罐觀關巖顏凾"
   "陷歸氣龜僞戲犧舊據擧峽挾狹曉區驅勳徑惠溪經繼莖"
   "螢輕鷄藝缺儉劍圈檢權獻縣險顯驗嚴效廣恆鑛號國濟"
   "碎齋册劑雜參蠶棧慘讚贊殘齒兒辭濕實舍寫釋壽收龝"
   "從澁獸縱肅處敍奬將燒稱證乘剩壤孃條淨疊穰讓釀觸"
   "寢愼晉眞盡繩圖粹醉穗隨髓數樞聲靜齊竊攝專戰淺濳"
   "纖踐錢禪壯雙搜插爭總聰莊裝騷臟藏屬續墮體對帶滯"
   "臺擇澤單擔膽團彈斷遲癡晝蟲鑄廳聽鎭遞鐵轉點傳"
   "兔黨當盜燈稻鬪獨讀貳惱腦廢拜賣麥發髮拔蠻濱拂佛"
   "變竝篦邊辨餠舖寶豐冐沒萬滿默來亂彌藥譯豫餘與譽"
   "搖樣謠覽兩獵壘勵禮靈齡戀爐勞樓瀧祿蘆灣祕囑劵敕"
   "豎廚禰"
   ;; 追加分1（既存）
   "硏說强內狀劃徵德靑增敎卽旣槪步歲黃每戶產溫辯瓣虛"
   "郞鄕綠橫絲曆遙眾飜姬俠絕淚閱"
   ;; 追加分2（官製常用漢字旧字体の漏れ＋剣の異体字＋人名頻出）
   "巢黑緣歷晚攜賴脫劒劔釼鷗廏"
   ;; 追加分3（拡張新字体・表外漢字）
   "醬麵蠟噓摑攪槇檜潑瀆瑤瘦簞顚繡蘂萊屢賤藪剝頰羡蹟瀨鹼窗卻卆礦鬭"
   ;; 追加分4（近代文献頻出：gemini分から重複除去後）
   "揭擊緖倂俱吞啞嚙囊塡姙屛曾渴豬襃霸鍊錄隸鄰"))

(defconst kreplace-shinjitai
  (concat
   ;; 原テーブル
   "亜悪圧囲医為壱飲隠欝営栄衛駅円艶塩奥応欧殴穏桜"
   "仮価画届会壊懐絵拡覚学岳楽殻勧巻歓缶観関巌顔函"
   "陥帰気亀偽戯犠旧拠挙峡挟狭暁区駆勲径恵渓経継茎"
   "蛍軽鶏芸欠倹剣圏検権献県険顕験厳効広恒鉱号国済"
   "砕斎冊剤雑参蚕桟惨讃賛残歯児辞湿実舎写釈寿収穐"
   "従渋獣縦粛処叙奨将焼称証乗剰壌嬢条浄畳穣譲醸触"
   "寝慎晋真尽縄図粋酔穂随髄数枢声静斉窃摂専戦浅潜"
   "繊践銭禅壮双捜挿争総聡荘装騒臓蔵属続堕体対帯滞"
   "台択沢単担胆団弾断遅痴昼虫鋳庁聴鎮逓鉄転点伝"
   "兎党当盗灯稲闘独読弐悩脳廃拝売麦発髪抜蛮浜払仏"
   "変並箆辺弁餅舗宝豊冒没万満黙来乱弥薬訳予余与誉"
   "揺様謡覧両猟塁励礼霊齢恋炉労楼滝禄芦湾秘嘱券勅"
   "竪厨祢"
   ;; 追加分1（既存）
   "研説強内状画徴徳青増教即既概歩歳黄毎戸産温弁弁虚"
   "郎郷緑横糸暦遥衆翻姫侠絶涙閲"
   ;; 追加分2（官製常用漢字旧字体の漏れ＋剣の異体字＋人名頻出）
   "巣黒縁歴晩携頼脱剣剣剣鴎厩"
   ;; 追加分3（拡張新字体・表外漢字）
   "醤麺蝋嘘掴撹槙桧溌涜瑶痩箪顛繍蕊莱屡賎薮剥頬羨跡瀬鹸窓却卒鉱闘"
   ;; 追加分4（近代文献頻出：gemini分から重複除去後）
   "掲撃緒併倶呑唖噛嚢填妊屏曽渇猪褒覇錬録隷隣"))

;; --- 互換漢字（しめすへん等の印刷標準字体, U+FAxx）への対処 ---
;; gemini版「強化分」行2・3が狙っていたのはこの互換漢字。これらは正準分解を
;; 持つため、テーブル列挙より NFC 正規化で前処理する方が網羅的かつ堅牢。
;; kreplace の変換前に文字列へ適用する。
(defun kreplace-normalize (str)
  "STR を NFC 正規化し、CJK 互換漢字（神社祖…など）を標準字体へ畳む。"
  (ucs-normalize-NFC-string str))

(defun kreplace ()
  "クリップボードの文字列を整形し、旧字体を新字体に変換して挿入"
  (interactive)
  (let* ((str (or (gui-get-selection 'CLIPBOARD) ""))
         ;; ^M(\r\n or \r)を\nに統一
         (str (replace-regexp-in-string "\r\n?" "\n" str))
         ;; 「。」「」」直後の改行を退避
         (str (replace-regexp-in-string "\\([。」]\\)\n" "\\1\0" str))
         ;; 残りの改行を除去
         (str (replace-regexp-in-string "\n" "" str))
         ;; 退避した改行を復元
         (str (replace-regexp-in-string "\0" "\n" str))
         ;; 水平空白・全角スペースを除去
         (str (replace-regexp-in-string "[ \t　]+" "" str))
         ;; 句読点変換
         (str (replace-regexp-in-string "," "、" str))
         (str (replace-regexp-in-string "\\." "。" str))
         ;; 旧字体→新字体
         (result-str (apply #'string
                            (seq-map (lambda (c)
                                       (if-let* ((pos (seq-position kreplace-kyujitai c)))
                                           (aref kreplace-shinjitai pos)
                                         c))
                                     str))))
    (insert result-str))))

(use-package kanahen
  :ensure nil
  :no-require t
  :bind ("C-c y" . kanahen)
  :init
  (defun kanahen (beg end)
    "リージョンのカタカナをひらがなに変換する。リージョン未選択時はエラー。"
    (interactive
     (if (use-region-p)
         (list (region-beginning) (region-end))
       (user-error "リージョンを選択してください")))
    (japanese-hiragana-region beg end)))

(use-package imenu-list
  :ensure t
  :bind ("C-c n" . imenu-list-smart-toggle)
  :custom
  (imenu-list-position 'left)
  (imenu-list-size 40)
  (imenu-list-auto-resize nil))

;;; Markdown
(use-package markdown-mode
  :ensure t
  :hook
  (markdown-mode . markdown-toggle-markup-hiding)
  :custom
  (markdown-fontify-code-blocks-natively t)
  (markdown-header-scaling t)
  (markdown-indent-on-enter 'indent-and-new-item)
  :config
  ;; 表示用に使うのでデフォルトのキーバインドは空にする。
  ;; setq で別マップに差し替えると gfm-mode-map 等が捕まえた旧参照に効かず、
  ;; :bind だとクリアとの順序が保証されないため、setcdr で空にしてから束縛する。
  (setcdr markdown-mode-map nil)
  (keymap-set markdown-mode-map "C-c I" #'my/markdown-paste-image-macos)
  (keymap-set markdown-mode-map "C-c C-i" #'markdown-toggle-inline-images)

(defun my/markdown-paste-image-macos ()
  (interactive)
  (unless (eq system-type 'darwin)
    (user-error "This function is for macOS only"))
  (unless (executable-find "pngpaste")
    (user-error "pngpaste is not installed"))
  
  (let* ((img-name (format-time-string "%Y%m%d_%H%M%S.png"))
         (img-dir (expand-file-name "images/" default-directory))
         (img-path (expand-file-name img-name img-dir))
         (rel-path (file-relative-name img-path default-directory)))
    
    (unless (file-exists-p img-dir)
      (make-directory img-dir t))
    
    (if (zerop (call-process "pngpaste" nil nil nil img-path))
        (progn
          (insert (format "![](%s)" rel-path))
          (message "Saved: %s" rel-path))
      (user-error "pngpaste failed; ensure an image is in the clipboard"))))

  (defun my/create-image-with-width (orig file &optional type data-p &rest props)
    (let ((type (or type (image-type file data-p))))
      (if (and (derived-mode-p 'markdown-mode)
               (eq type 'png))
          (apply orig file type data-p (plist-put props :scale 0.4))
        (apply orig file type data-p props))))
  (advice-add 'create-image :around #'my/create-image-with-width))

(use-package uniquify
  :custom
  (uniquify-ignore-buffers-re "^\\*"))

(use-package super-save
  :ensure t
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-idle-duration 1)
  (save-silently t)
  :config
  (add-to-list 'super-save-triggers 'switch-window)
  (super-save-mode 1))

;;; So Long
;(use-package so-long
;  :init
;  (global-so-long-mode 1))

(use-package savehist
  :custom
  (savehist-additional-variables '(kill-ring))
  :hook (after-init . savehist-mode))

(use-package saveplace
  :hook (after-init . save-place-mode))

;;; Auto Revert
(use-package autorevert
  :defer t
  :custom
  (auto-revert-interval 1)
  :init
  (run-with-idle-timer 1.0 nil #'global-auto-revert-mode))

;;; 検索ツール
(use-package deadgrep
  :ensure t
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
  :defer t
  :custom
  (recentf-max-saved-items 2000)
  (recentf-auto-cleanup 'never)
  (recentf-exclude '("^/tmp/"
                     "/\\.git/"))
  :init
  (run-with-idle-timer 1 nil #'recentf-mode)
  :config
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
  (setq lookup-open-function 'lookup-full-screen))

(use-package prescient
  :ensure t
  :custom
  (prescient-aggressive-file-save t)
  ;; :ensure t のパッケージは after-init-hook 実行後に有効化されるため
  ;; after-init に掛けると発火しない。elpaca 側のフックを使う
  :hook (elpaca-after-init . prescient-persist-mode))

(use-package vertico-prescient
  :ensure t
  :after vertico
  :custom
  (vertico-prescient-enable-filtering nil)
  :init
  (vertico-prescient-mode 1))

(use-package dirvish
  :ensure t
  :defer t
  :init
  (with-eval-after-load 'dired
    (dirvish-override-dired-mode))
  :custom
  (dirvish-default-layout '(0 0.4 0.6))
  (dirvish-use-header-line 'global)
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
          ("c" ,(expand-file-name "~/.emacs.d/")   ".emacs.d")
	  ("g" ,(expand-file-name "~/Documents/github/")   "Github")
	  ))
  :bind
  (:map dirvish-mode-map
        ("a" . dirvish-quick-access)
        ("f" . dirvish-file-info-menu)
        ("y" . dirvish-yank-menu)
        ("s" . dirvish-quicksort)
        ("TAB" . dirvish-subtree-toggle)
        ("<backspace>" . dired-up-directory)))

;;; BM
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
  ;; after-init だと elpaca の有効化タイミングに間に合わず発火しない
  (elpaca-after-init . bm-repository-load)
  (kill-buffer . bm-buffer-save)
  (after-save . bm-buffer-save)
  (find-file . bm-buffer-restore)
  (after-revert . bm-buffer-restore)
  (vc-before-checkin . bm-buffer-save)
  (kill-emacs . (lambda () (ignore-errors (bm-repository-save)))))

;;; Magit
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
  (git-commit-summary-max-length 999)
  (git-commit-style-convention-checks nil)
  :config
  ;; git-commit-fill-column は magit 4.x で廃止。fill-column を直接設定する
  (add-hook 'git-commit-setup-hook (lambda () (setq fill-column 999))))

(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

;;; 日本語入力 & 変換 (DDSKK / Dabbrev)
(defun my/dabbrev-japanese-regexp ()
  "カーソル直前の文字種に応じたdabbrev用正規表現を返す。"
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

(with-eval-after-load 'dabbrev
  (defvar dabbrev-abbrev-char-regexp)
  (define-advice dabbrev-expand (:around (orig-fn &rest args) japanese-support)
    (let ((dabbrev-abbrev-char-regexp
           (or (my/dabbrev-japanese-regexp)
               dabbrev-abbrev-char-regexp)))
      (apply orig-fn args))))
(setq hippie-expand-try-functions-list
      '(try-expand-dabbrev
        try-expand-dabbrev-all-buffers
        try-complete-file-name-partially
        try-complete-file-name))

;; skk がロード時に require するので起動時には読み込まない
(use-package ccc
  :ensure (:version (lambda (_) "1.43"))
  :defer t)

(use-package skk-lookup
  :ensure nil
  :defer t
  :config
  (setq skk-lookup-search-agents
        (cl-remove-if (lambda (x) (memq (car x) '(ndkks ndcookie ndnmz)))
                     lookup-search-agents))
  (let ((add-opt (lambda (dic-name regexp split)
                   (add-to-list 'skk-lookup-option-alist
                                (list dic-name 'exact 'exact 'exact t regexp split nil)))))
    (dolist (dic-name '("kojien" "jirin21" "hot01" "skpkogo2" "skpkoku2" "skpkoji2" "hyogen"))
      (funcall add-opt dic-name '("【\\([^】]+\\)】" . 1) "・"))
    (funcall add-opt "skpknw2" '("^【\\([^】]+\\)】" . 1) nil)
    (funcall add-opt "mypaedia" '("（\\([^）]+\\)）" . 1) "／")
    (funcall add-opt "chujiten" '("\\s-+\\(.+\\)$" . 1) nil)
    (funcall add-opt "nihonshi" '("^\\([^【]+\\)【" . 1) nil)
    (dolist (dic-name '("ssn" "ency" "chimei" "jinmei"))
      (funcall add-opt dic-name nil nil))))

;;; DDSKK
(use-package ddskk
  :ensure (:version (lambda (_) "17.2"))
;  :ensure t
  :init
  (setq skk-user-directory (expand-file-name "~/.skk.d"))
  :bind
  ("M-o" . skk-mode)
  :preface
  (defun skk-open-server-decoding-utf-8 ()
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
  (skk-indicator-use-cursor-color t)
  (skk-inhibit-ja-dic-search t)
  (skk-latin-mode-string "[_A]")
  (skk-hiragana-mode-string "[あ]")
  (skk-katakana-mode-string "[ア]")
  (skk-jisx0208-latin-mode-string "[Ａ]")
  (skk-jisx0201-mode-string "[_ｱ]")
  (skk-abbrev-mode-string "[aA]")
  (skk-status-indicator 'left)
  (skk-rom-kana-rule-list
   '((";" nil nil)
     (":" nil nil)
     ("?" nil nil)
     ("!" nil nil)))
  :config
  ;; インジケータ設定
  (define-advice skk-make-indicator-alist (:filter-return (alist) my-indicator)
    (dolist (elem '((abbrev " [aA]" . "--[aA]:")
                    (latin " [_A]" . "--[_A]:")
                    (default " [--]" . "--[--]:")))
      (setq alist (cons elem (assq-delete-all (car elem) alist))))
    alist)
;;lookup
  (require 'lookup)
  (unless (fboundp 'lookup-foreach)
    (defalias 'lookup-foreach #'mapc))
  (require 'skk-bayesian)
  (require 'skk-lookup)
  (setq skk-search-prog-list
        '((skk-search-jisyo-file skk-jisyo 0 t)
          (skk-search-kakutei-jisyo-file skk-kakutei-jisyo 10000 t)
          (skk-search-jisyo-file skk-initial-search-jisyo 10000 t)
          (skk-search-server skk-aux-large-jisyo 10000)
	  (skk-lookup-search)
          )))

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
  (doom-modeline-height 25)
  (doom-modeline-major-mode-color-icon nil)
  (doom-modeline-bar-width 3)
  (doom-modeline-vcs-max-length 12)
  :custom-face
  (mode-line ((t (:box nil))))
  (mode-line-inactive ((t (:box nil))))
  :config
  (doom-modeline-def-segment my-buffer-size
    "Display current buffer size"
    (format "%s" (buffer-size)))
  (doom-modeline-def-modeline 'main
    '(buffer-encoding bar workspace-name buffer-info " ¦¦" vcs)
    '(misc-info " ¦" "✎" my-buffer-size "  |  "  major-mode))
  (doom-modeline-mode 1))

;;; 便利ツール & 自作関数

(use-package dmacro
  :ensure t
  :bind ("C-M-'" . dmacro-exec))

(use-package nhg-minor-mode
  :ensure (nhg-minor-mode
           :url "https://github.com/ichibeikatura/nhg-minor-mode")
  :defer t
  :hook ((text-mode markdown-mode) . nhg-minor-mode))

(use-package proofreader
  :ensure (proofreader
           :url "https://github.com/ichibeikatura/proofreader.el")
  :defer t
  :commands (proofreader-send-buffer
             proofreader-send-region
             proofreader-apply-interactive
             proofreader-apply
             proofreader-open-json))

(use-package ndl-note-tag
  :ensure (ndl-note-tag
           :url "https://github.com/ichibeikatura/ndl-note-tag")
  :defer t
  :bind ("C-M-]" . ndl-note-tag-insert)
  :init
  (add-to-list 'display-buffer-alist
               '("\\`\\*ndl-tags\\*\\'"
                 (display-buffer-in-side-window)
                 (side . left)
                 (slot . 0)
                 (window-width . 40)
                 (preserve-size . (t . nil))
                 (window-parameters . ((no-delete-other-windows . t)))))
:custom (ndl-note-tag-list-select-window nil)
  )

(use-package year-convert
  :ensure (year-convert
           :url "https://github.com/ichibeikatura/year-convert")
  :defer t
  :bind ("C-M-=" . year-convert-at-point))

(use-package zellij-send
  :ensure (zellij-send
           :url "https://github.com/ichibeikatura/zellij-send.el")
  :defer t
  :commands (zellij-send))

(use-package post-hatena
  :ensure (post-hatena
           :url "https://github.com/ichibeikatura/post-hatena.el")
  :defer t
  :commands (post-hatena post-hatena-draft)
  :custom
  (post-hatena-hatena-id "cocolog-nifty")
  (post-hatena-blog-id "cocolog-nifty.hatenablog.com"))

  (elpaca (ndl-search
           :url "https://github.com/ichibeikatura/ndl-search")
    (autoload 'ndl-search "ndl-search" nil t))

(defun my/epub-convert ()
  (interactive)
  (when (buffer-modified-p) (save-buffer))
  (let ((script-path (expand-file-name "~/Documents/github/convert_epub/convert_epub.py")))
    (message "Generating EPUB...")
    (shell-command-on-region (point-min) (point-max) (concat "python3 " script-path))
    (message "EPUB generation sent.")))

(defun my/insert-diary-entry ()
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

(defvar my/junk-file-directory (expand-file-name "~/My Drive/memo/")
  "Junkファイルの保存ディレクトリ")
(defun open-junk-file ()
  (interactive)
  (let ((file (expand-file-name
               (format-time-string "%Y_%m_%d_%H_%M_%S.txt" (current-time))
               my/junk-file-directory)))
    (find-file file)
    (insert (format-time-string "%Y-%m-%d %H:%M\n" (current-time)))
    (insert "#title: ")))

(defun my/native-comp-packages ()
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
        (native-compile-async dir t)))))

;; init.el ends here
