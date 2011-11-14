;;; Commentary:
;;
;; org-confluence.el lets you convert Org files to confluence files using
;; the org-export.el experimental engine.
;;
;; Put this file into your load-path and the following into your ~/.emacs:
;;	 (require 'org-confluence)
;;
;; Export Org files to confluence: M-x org-confluence-export RET
;;
;;; Code:

(require 'org-export)

(defvar org-confluence-emphasis-alist
  '(("*" "*%s*" nil)
	("/" "_%s_" nil)
	("_" "+%s+" nil)
	("+" "-%s-" nil)
	("~" "\{\{%s\}\}" nil)
	("=" "\{\{%s\}\}" nil))
  "The list of fontification expressions for confluence.")

(setq org-confluence-link-analytic-regexp
	(concat
	 "\\[\\["
	 "\\(\\(" (mapconcat 'regexp-quote (cons "confluence" org-link-types) "\\|") "\\):\\)?"
	 "\\([^]]+\\)"
	 "\\]"
	 "\\(\\[" "\\([^]]+\\)" "\\]\\)?"
	 "\\]"))


(defun org-confluence-export ()
  "Export the current buffer to Confluence."
  (interactive)
  (setq org-export-current-backend 'confluence)
  (org-export-set-backend "confluence")
  (org-export-render))

(defun org-confluence-export-header ()
  "Export the header part."
  (let* ((p (org-combine-plists (org-infile-export-plist)
                                org-export-properties)))
    (if (plist-get p :table-of-contents)
        (insert "\{toc\}\n"))))

(defun org-confluence-export-first-lines (first-lines)
  "Export first lines."
  (insert (org-export-render-content first-lines) "\n")
  (goto-char (point-max)))

(defun org-confluence-export-heading (section-properties)
  "Export confluence heading"
  (let* ((p section-properties)
	 (h (plist-get p :heading))
	 (s (plist-get p :level)))
	(insert (format "h%s. %s\n" s h ))))

(defun org-confluence-export-quote-verse-center ()
  "Export #+BEGIN_QUOTE/VERSE/CENTER environments."
  (let (rpl e)
    (while (re-search-forward "^[ \t]*ORG-\\([A-Z]+\\)-\\(START\\|END\\).*$" nil t)
      (replace-match "" t))))

(defun org-confluence-export-links ()
  "Replace Org links with confluence links."
  ;; FIXME: This function could be more clever, of course.
  (while (re-search-forward org-confluence-link-analytic-regexp nil t)
	(cond ((and (equal (match-string 1) "file:")
                (save-match-data
                  (string-match (org-image-file-name-regexp) (match-string 3))))
           (replace-match  (concat "!" (file-name-nondirectory (match-string 3)))))
          ((equal (match-string 1) "confluence:")
           (replace-match (concat "[\\3]")))
          (t 
           (replace-match (concat "[" (if (match-string 5) "\\5|" "") "\\1\\3]"))))))

(defun org-confluence-format-source-code-or-example (lines lang caption textareap
                                                           cols rows num cont
                                                           rpllbl fmt)
  "format source and example blocks"
  (concat "\{code}\n"
          (concat
           (mapconcat
			(lambda (l) l)
			(org-split-string lines "\n")
			"\n")
           "\n\{code\}\n")
          ))

(defun org-confluence-export-lists ()
  "Export lists to Confluence syntax."
  (while (re-search-forward (org-item-beginning-re) nil t)
	(move-beginning-of-line 1)
	(insert (org-list-to-generic
		 (org-list-parse-list t)
		 (org-combine-plists
		  '(:splice nil 
			:ostart "" :oend ""
			:ustart "" :uend ""
			:dstart "" :dend ""
			:dtstart "" :dtend ""
			:istart (concat
					 (make-string 
					  (1+ depth) (if (eq type 'unordered) ?* ?#)) " ")
			:iend ""
            :isep "\n"
			:icount nil
			:csep "\n"
			:cbon "[X]" :cboff "[ ]"
			:cbtrans "[-]"))))))

(defun org-confluence-export-tables ()
  "Convert tables in the current buffer to confluence tables."
  (while (re-search-forward "^\\([ \t]*\\)|" nil t)
	(org-if-unprotected-at (1- (point))
	  (org-table-align)
	  (let* ((beg (org-table-begin))
			 (end (org-table-end))
			 (raw-table (buffer-substring beg end)) lines)
	(setq lines (org-split-string raw-table "\n"))
	(apply 'delete-region (list beg end))
	(when org-export-table-remove-special-lines
	  (setq lines (org-table-clean-before-export lines 'maybe-quoted)))
	(setq lines
		  (mapcar
		   (lambda(elem)
		 (or (and (string-match "[ \t]*|-+" elem) 'hline)
			 (org-split-string (org-trim elem) "|")))
		   lines))
	(insert (orgtbl-to-confluence lines nil))))))

(defun orgtbl-to-confluence (table params)
  "Convert TABLE into a confluence table."
  (let ((params2 (list
		  :lstart "| "
		  :lend " |"
		  :sep " | "
		  :hlstart "|| "
          :hllstart "|| "
		  :hlend " ||"
		  :hlsep " || "
		  )))
	(orgtbl-to-generic table (org-combine-plists params2 params))))

(defun org-confluence-export-fonts ()
  "Export fontification."
  (while (re-search-forward org-emph-re nil t)
    (let* ((emph (assoc (match-string 3) org-confluence-emphasis-alist))
	   (beg (match-beginning 0))
	   (begs (match-string 1))
	   (end (match-end 0))
	   (ends (match-string 5))
	   (rpl (format (cadr emph) (match-string 4))))
      (delete-region beg end)
      (insert begs rpl ends)))
  
    
)

;; Various empty function for org-export.el to work:
(defun org-confluence-export-footer () "")
(defun org-confluence-export-section-beginning (section-properties) "")
(defun org-confluence-export-section-end (section-properties) "")
(defun org-confluence-export-footnotes () "")

(defun org-export-confluence-preprocess (parameters)
  "Do extra work for Confluence export."
  nil)

(provide 'org-confluence)
