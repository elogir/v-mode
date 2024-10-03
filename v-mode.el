;;; v-mode.el --- A major mode for the V programming language  -*- lexical-binding: t; -*-

;; Copyright (c) 2020 Damon Kwok

;; Authors: Damon Kwok <damon-kwok@outlook.com>
;; Version: 0.0.1
;; URL: https://github.com/damon-kwok/v-mode
;; Keywords: languages programming
;; Package-Requires: ((emacs "25.1") (dash "2.17.0") (hydra "0.15.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Description:
;;
;; This is a major mode for the V programming language
;;
;; For more details, see the project page at
;; https://github.com/damon-kwok/v-mode
;;
;; Installation:
;;
;; The simple way is to use package.el:
;;
;;   M-x package-install v-mode
;;
;; Or, copy v-mode.el to some location in your Emacs load
;; path.  Then add "(require 'v-mode)" to your Emacs initialization
;; (.emacs, init.el, or something).
;;
;; Example config:
;;
;;   (require 'v-mode)
;;
;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'js)
(require 'imenu)

(defvar v-mode-hook nil)

(defconst v-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; fontify " using v-keywords

    ;; Operators
    (dolist (i '(?+ ?- ?* ?/ ?% ?& ?| ?= ?! ?< ?>))
      (modify-syntax-entry i "." table))

    ;; / is punctuation, but // is a comment starter
    (modify-syntax-entry ?/ ". 124" table)

    ;; /* */ comments, which can be nested
    ;; (modify-syntax-entry ?* ". 23bn" table)
    ;; (modify-syntax-entry ?\n ">" table)

    ;; uses // for comments
    (modify-syntax-entry ?/  ". 12" table)
    (modify-syntax-entry ?\n ">"    table)

    ;; string
    (modify-syntax-entry ?\` "\"" table)
    (modify-syntax-entry ?\' "\"" table)
    (modify-syntax-entry ?\" "\"" table)

    ;; Don't treat underscores as whitespace
    (modify-syntax-entry ?_ "w" table) table))

(defconst v-keywords '("if" "else" "for" "match")
  "V language keywords.")

;;;###autoload
(defgroup v-mode nil
  "Major mode for editing V code."
  :prefix "v-"
  :group 'languages)

(defcustom v-declaration-keywords
                                        ;
  '("type" "interface" "struct" "enum" "fn")
  "V declaration keywords."
  :type '(repeat string)
  :group 'v-mode)

(defcustom v-preprocessor-keywords '("module" "pub" "const")
  "V preprocessor keywords."
  :type '(repeat string)
  :group 'v-mode)

(defcustom v-careful-keywords
  '("import"                            ;
    "break" "continue" "return" "goto" ;
    "defer" "panic" "error"            ;
    "in" "is" "or"                     ;
    "go" "inline" "live"               ;
    "as" "assert"  "unsafe" "mut"      ;
    "__global" "C")
  "V language careful keywords."
  :type '(repeat string)
  :group 'v-mode)

(defcustom v-builtin-keywords
  '("string" "bool"                         ;
    "i8" "i16" "int" "i64" "i128"          ;
    "byte" "u16" "u32" "u64" "u128"        ;
    "rune"                                 ;
    "f32" "f64"                            ;
    "byteptr" "voidptr" "charptr" "size_t" ;
    "any" "any_int" "any_float"            ;
    "it")
  "V language keywords."
  :type '(repeat string)
  :group 'v-mode)

(defcustom v-constants                  ;
  '("false" "true" "none")
  "Common constants."
  :type '(repeat string)
  :group 'v-mode)

(defcustom v-operator-functions '()
  "V language operators functions."
  :type '(repeat string)
  :group 'v-mode)

;; create the regex string for each class of keywords

(defconst v-keywords-regexp (regexp-opt v-keywords 'words)
  "Regular expression for matching keywords.")

(defconst v-declaration-keywords-regexp
                                        ;
  (regexp-opt v-declaration-keywords 'words)
  "Regular expression for matching declaration keywords.")

(defconst v-preprocessor-keywords-regexp
                                        ;
  (regexp-opt v-preprocessor-keywords 'words)
  "Regular expression for matching preprocessor keywords.")

(defconst v-careful-keywords-regexp
                                        ;
  (regexp-opt v-careful-keywords 'words)
  "Regular expression for matching careful keywords.")

(defconst v-builtin-keywords-regexp (regexp-opt v-builtin-keywords 'words)
  "Regular expression for matching builtin type.")

(defconst v-constant-regexp             ;
  (regexp-opt v-constants 'words)
  "Regular expression for matching constants.")

(defconst v-operator-functions-regexp
                                        ;
  (regexp-opt v-operator-functions 'words)
  "Regular expression for matching operator functions.")

(defvar v-font-lock-keywords
  `(
    ;; builtin
    (,v-builtin-keywords-regexp . font-lock-builtin-face)

    ;; careful
    (,v-careful-keywords-regexp . font-lock-warning-face)

    ;; @ # $
    ;; ("#\\(?:include\\|flag\\)" . 'font-lock-builtin-face)
    ("[@#$][A-Za-z_]*[A-Z-a-z0-9_]*" . 'font-lock-warning-face)

    ;; declaration
    (,v-declaration-keywords-regexp . font-lock-keyword-face)

    ;; preprocessor
    (,v-preprocessor-keywords-regexp . font-lock-preprocessor-face)

    ;; delimiter: modifier
    ("\\(->\\|=>\\|\\.>\\|:>\\|:=\\|\\.\\.\\||\\)" 1 'font-lock-keyword-face)

    ;; delimiter: . , ; separate
    ("\\($?[.,;]+\\)" 1 'font-lock-comment-delimiter-face)

    ;; delimiter: operator symbols
    ("\\($?[+-/*//%~=<>]+\\)$?,?" 1 'font-lock-negation-char-face)
    ("\\($?[?^!&]+\\)" 1 'font-lock-warning-face)

    ;; delimiter: = : separate
    ("[^+-/*//%~^!=<>]\\([=:]\\)[^+-/*//%~^!=<>]" 1
     'font-lock-comment-delimiter-face)

    ;; delimiter: brackets
    ("\\(\\[\\|\\]\\|[(){}]\\)" 1 'font-lock-comment-delimiter-face)

    ;; numeric literals
    ;; ("[^A-Za-z_]\\([0-9][A-Za-z0-9_]*\\)" 1 'font-lock-constant-face)
    ("[ \t/+-/*//=><([{,;&|%]\\([0-9][A-Za-z0-9_]*\\)" 1
     'font-lock-constant-face)

    ;; operator methods
    (,v-operator-functions-regexp . font-lock-builtin-face)

    ;; method definitions
    ("\\(?:fn\\)\s+\\($?[a-z_][A-Za-z0-9_]*\\)" 1
     'font-lock-function-name-face)

    ;; type
    ("\\([A-Z][A-Za-z0-9_]*\\)" 1 'font-lock-type-face)

    ;; constants references
    (,v-constant-regexp . font-lock-constant-face)

    ;; method references
    ("\\([a-z_]$?[a-z0-9_]?+\\)$?[ \t]?(+" 1 'font-lock-function-name-face)

    ;; parameter
    ("\\(?:(\\|,\\)\\([a-z_][a-z0-9_']*\\)\\([^ \t\r\n,:)]*\\)" 1
     'font-lock-variable-name-face)
    ("\\(?:(\\|,\\)[ \t]+\\([a-z_][a-z0-9_']*\\)\\([^ \t\r\n,:)]*\\)" 1
     'font-lock-variable-name-face)

    ;; tuple references
    ("[.]$?[ \t]?\\($?_[1-9]$?[0-9]?*\\)" 1 'font-lock-variable-name-face)

    ;; keywords
    (,v-keywords-regexp . font-lock-keyword-face) ;;font-lock-keyword-face

    ;; character literals
    ("\\('[\\].'\\)" 1 'font-lock-constant-face)

    ;; variable references
    ("\\($?_?[a-z]+[a-z_0-9]*\\)" 1 'font-lock-variable-name-face))
  "An alist mapping regexes to font-lock faces.")

;;;###autoload
(define-derived-mode v-mode prog-mode
  "V"
  "Major mode for editing V files."
  :syntax-table v-mode-syntax-table
  ;;
  (setq-local require-final-newline mode-require-final-newline)
  (setq-local parse-sexp-ignore-comments t)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-multi-line t)
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *")
  ;;
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)
  (setq-local buffer-file-coding-system 'utf-8-unix)
  ;;
  (setq-local electric-indent-chars (append "{}():;," electric-indent-chars))
  (setq-local indent-line-function #'js-indent-line)
  (setq-local js-indent-level tab-width)
  ;;
  (setq-local font-lock-defaults '(v-font-lock-keywords))
  (font-lock-flush)
  ;;
  (setq-local imenu-generic-expression ;;
              '(("TODO" ".*TODO:[ \t]*\\(.*\\)$" 1)
                ("fn" "[ \t]*fn[ \t]+(.*)[ \t]+\\(.*\\)[ \t]*(.*)" 1)
                ("struct" "[ \t]*struct[ \t]+\\([a-zA-Z0-9_]+\\)" 1)
                ("interface" "[ \t]*interface[ \t]+\\([a-zA-Z0-9_]+\\)" 1)
                ("type" "[ \t]*type[ \t]+\\([a-zA-Z0-9_]+\\)" 1)
                ("enum" "[ \t]*enum[ \t]+\\([a-zA-Z0-9_]+\\)" 1)
                ("import" "[ \t]*import[ \t]+\\([a-zA-Z0-9_]+\\)" 1)))
  (imenu-add-to-menubar "Index"))

;;;###autoload
(setq auto-mode-alist
      (cons '("\\(\\.v?v\\|\\.vsh\\)$" . v-mode) auto-mode-alist))

;;
(provide 'v-mode)

;;; v-mode.el ends here
