;;; init-tests.el --- Configuration regression tests -*- lexical-binding: t; -*-
;; Run: Emacs --batch -Q -l tests/init-tests.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'ucs-normalize)
(setq native-comp-jit-compilation nil
      native-comp-enable-subr-trampolines nil)

;; Load only the functions under test, without starting Elpaca or global modes.
(let ((init-file (expand-file-name "../init.el"
                                   (file-name-directory (or load-file-name buffer-file-name))))
      (functions '(my/nfc-compose-string my/normalize-nfc-region
                   my/normalize-nfc-string my/normalize-nfc-buffer
                   my/save-buffer-keep-mark my/change-font
                   my/markdown-paste-image-macos my/insert-diary-entry)))
  (with-temp-buffer
    (insert-file-contents init-file)
    (goto-char (point-min))
    (condition-case nil
        (while t
          (let ((form (read (current-buffer))))
            (when (or (and (eq (car-safe form) 'defun)
                           (memq (cadr form) functions))
                      (and (eq (car-safe form) 'defvar)
                           (memq (cadr form) '(my-font-alist my-current-font-name
                                               my-current-font-size)))
                      (and (eq (car-safe form) 'define-advice)
                           (memq (cadr form) '(insert-for-yank gui-get-selection))))
              (eval form t))))
      (end-of-file nil))))

(ert-deftest init-nfc-preserves-selection-in-both-directions ()
  (dolist (positions '((3 1 2 1) (1 3 1 2) (4 3 3 2) (3 4 2 3)))
    (with-temp-buffer
      (insert "か\u3099ABC")
      (goto-char (nth 0 positions))
      (set-mark (nth 1 positions))
      (setq mark-active t)
      (let ((deactivate-mark nil))
        (my/normalize-nfc-buffer)
        (should (equal (buffer-string) "がABC"))
        (should (= (point) (nth 2 positions)))
        (should (= (mark) (nth 3 positions)))
        (should mark-active)
        (should-not deactivate-mark)))))

(ert-deftest init-nfc-tracks-selection-after-multiple-compositions ()
  (with-temp-buffer
    (insert "か\u3099き\u3099ABC")
    (goto-char 6)
    (set-mark 5)
    (my/normalize-nfc-buffer)
    (should (equal (buffer-substring (mark) (point)) "A"))))

(ert-deftest init-nfc-preserves-attributes-through-composition-and-reordering ()
  (let* ((source (concat (propertize "a" 'face 'bold 'help-echo "base")
                         (propertize "\u0301" 'face 'italic 'language "accent")
                         (propertize "\u0327" 'face 'underline)))
         (result (my/normalize-nfc-string source)))
    (should (equal result (ucs-normalize-NFC-string (substring-no-properties source))))
    (should (eq (get-text-property 0 'face result) 'bold))
    (should (equal (get-text-property 0 'help-echo result) "base"))
    (should (equal (get-text-property 0 'language result) "accent"))
    (should (eq (get-text-property 1 'face result) 'underline))))

(ert-deftest init-nfc-matches-unicode-normalization ()
  (dolist (source '("か\u3099ABC" "a\u0301\u0327" "\u212B"
                    "\u1100\u1161\u11A8" "\u0958" "\u0344"
                    "\u0301\u0327" "がABC" ""))
    (should (equal (my/normalize-nfc-string source)
                   (ucs-normalize-NFC-string source)))))

(ert-deftest init-nfc-noop-keeps-buffer-unmodified ()
  (with-temp-buffer
    (insert (propertize "がABC" 'face 'bold))
    (set-buffer-modified-p nil)
    (my/normalize-nfc-buffer)
    (should-not (buffer-modified-p))
    (should (eq (get-text-property 1 'face) 'bold))))

(ert-deftest init-nfc-skips-read-only-and-binary-content ()
  (with-temp-buffer
    (insert "か\u3099 き\u3099")
    (put-text-property 1 3 'read-only t)
    (my/normalize-nfc-buffer)
    (should (equal (buffer-string) "か\u3099 ぎ"))
    (setq buffer-read-only t)
    (my/normalize-nfc-buffer))
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert (unibyte-string #xe3 #x81 #x8b #xe3 #x82 #x99))
    (let ((before (buffer-string)))
      (my/normalize-nfc-buffer)
      (should (equal before (buffer-string))))))

(ert-deftest init-nfc-normalizes-whole-buffer-when-narrowed ()
  (with-temp-buffer
    (insert "か\u3099\nき\u3099\n")
    (narrow-to-region 4 7)
    (my/normalize-nfc-buffer)
    (should (buffer-narrowed-p))
    (widen)
    (should (equal (buffer-string) "が\nぎ\n"))))

(ert-deftest init-nfc-open-then-save-persists-normalized-text ()
  (let ((file (make-temp-file "init-nfc-" nil ".data"))
        (find-file-hook '(my/normalize-nfc-buffer))
        (before-save-hook '(my/normalize-nfc-buffer))
        (make-backup-files nil)
        (auto-save-default nil)
        buffer)
    (unwind-protect
        (progn
          (with-temp-file file (insert "か\u3099ABC"))
          (setq buffer (find-file-noselect file))
          (with-current-buffer buffer
            (should (buffer-modified-p))
            (save-buffer)
            (should-not (buffer-modified-p)))
          (with-temp-buffer
            (insert-file-contents file)
            (should (equal (buffer-string) "がABC"))))
      (when (buffer-live-p buffer) (kill-buffer buffer))
      (delete-file file))))

(ert-deftest init-nfc-yank-and-yank-pop-preserve-text-and-position ()
  (with-temp-buffer
    (let ((kill-ring (list (propertize "か\u3099" 'face 'bold) "second"))
          kill-ring-yank-pointer
          (interprogram-paste-function nil))
      (insert "AB")
      (goto-char 2)
      (yank)
      (should (equal (buffer-string) "AがB"))
      (should (= (point) 3))
      (should (eq (get-text-property 2 'face) 'bold))
      (let ((last-command 'yank)) (yank-pop 1))
      (should (equal (buffer-string) "AsecondB")))))

(ert-deftest init-nfc-save-keeps-selection-and-adds-final-newline ()
  (let ((file (make-temp-file "init-save-" nil ".data"))
        (before-save-hook '(my/normalize-nfc-buffer))
        (make-backup-files nil))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name file
                require-final-newline t)
          (insert "か\u3099ABC")
          (set-mark 1)
          (goto-char 3)
          (setq mark-active t)
          (let ((deactivate-mark nil))
            (my/save-buffer-keep-mark #'basic-save-buffer)
            (should (equal (buffer-string) "がABC\n"))
            (should (equal (buffer-substring (mark) (point)) "が"))
            (should mark-active)
            (should-not deactivate-mark)
            (should-not (buffer-modified-p))))
      (delete-file file))))

(ert-deftest init-image-paste-keeps-both-images-in-the-same-second ()
  (let ((default-directory (file-name-as-directory (make-temp-file "init-images-" t)))
        (native-comp-enable-subr-trampolines nil)
        (system-type 'darwin)
        paths)
    (unwind-protect
        (with-temp-buffer
          (cl-letf (((symbol-function 'format-time-string) (lambda (&rest _) "20260909_120000-"))
                    ((symbol-function 'executable-find) (lambda (&rest _) "/fake/pngpaste"))
                    ((symbol-function 'call-process)
                     (lambda (_program _in _out _display path)
                       (push path paths)
                       (with-temp-file path (insert (format "image-%d" (length paths))))
                       0)))
            (my/markdown-paste-image-macos)
            (my/markdown-paste-image-macos)
            (should (= (length (delete-dups (copy-sequence paths))) 2))
            (should (= (length (directory-files "images/" nil "\\.png\\'")) 2))
            (dolist (path paths)
              (should (string-match-p (regexp-quote (file-relative-name path)) (buffer-string)))))
          (with-temp-buffer
            (insert-file-contents (cadr paths))
            (should (equal (buffer-string) "image-1"))))
      (delete-directory default-directory t))))

(ert-deftest init-image-paste-cleans-up-failed-output ()
  (let ((default-directory (file-name-as-directory (make-temp-file "init-images-" t)))
        (native-comp-enable-subr-trampolines nil)
        (system-type 'darwin))
    (unwind-protect
        (with-temp-buffer
          (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "/fake/pngpaste"))
                    ((symbol-function 'call-process) (lambda (&rest _) 1)))
            (should-error (my/markdown-paste-image-macos) :type 'user-error)
            (should (equal (buffer-string) ""))
            (should-not (directory-files "images/" nil "\\.png\\'"))))
      (delete-directory default-directory t))))

(ert-deftest init-font-requires-a-known-name-with-a-default ()
  (let ((my-current-font-name "Mplus 1 code")
        (my-current-font-size 14))
    (cl-letf (((symbol-function 'completing-read)
               (lambda (_prompt _collection _predicate require-match _history _hist default &rest _)
                 (should require-match)
                 (should (equal default "Mplus"))
                 "typo")))
      (should-error (my/change-font) :type 'user-error)
      (should (equal my-current-font-name "Mplus 1 code"))
      (should (= my-current-font-size 14)))))

(ert-deftest init-diary-rejects-malformed-or-impossible-dates ()
  (dolist (date '("" "2026" "202609090" "abcdefgh" "20260229" "20260431" "20261301" "00000101"))
    (with-temp-buffer
      (let ((calls 0))
        (cl-letf (((symbol-function 'read-string)
                   (lambda (&rest _)
                     (cl-incf calls)
                     date)))
          (should-error (my/insert-diary-entry) :type 'user-error)
          (should (= calls 1))
          (should (equal (buffer-string) "")))))))

(ert-deftest init-diary-accepts-leap-day-and-preserves-layout ()
  (with-temp-buffer
    (let ((answers '("20240229" "山田 太郎の本")))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) (pop answers))))
        (my/insert-diary-entry))
      (should (equal (buffer-string) "2024年02月29日 | 山田\n\n出典:山田 太郎の本\n\n----\n"))
      (should (= (line-number-at-pos) 2)))))

;;; init-tests.el ends here
