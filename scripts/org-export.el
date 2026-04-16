(require 'org)
(require 'org-element)


;; org-element--parse-generic-emphasis hardcodes ASCII-only character
;; classes for emphasis boundaries, breaking ~code~ adjacent to CJK
;; characters. Override to include [:multibyte:] in pre/post sets.
(defun org-element--parse-generic-emphasis (mark type)
  "Parse emphasis object at point, if any.
MARK is the delimiter string used.  TYPE is a symbol among
`bold', `code', `italic', `strike-through', `underline', and
`verbatim'.  Assume point is at first MARK."
  (save-excursion
    (let ((origin (point)))
      (unless (bolp) (forward-char -1))
      (let ((opening-re
             (format "\\(?:^\\|[- \t('\"\\{[:multibyte:]]\\)%s[^ ]"
                     (regexp-quote mark))))
        (when (looking-at-p opening-re)
          (goto-char (1+ origin))
          (let ((closing-re
                 (format "[^ ]\\(%s\\)\\(?:[- \t.,;:!?'\")}\\\\\\[[:multibyte:]]\\|$\\)"
                         (regexp-quote mark))))
            (when (re-search-forward closing-re nil t)
              (let ((closing (match-end 1)))
                (goto-char closing)
                (let* ((post-blank (skip-chars-forward " \t"))
                       (contents-begin (1+ origin))
                       (contents-end (1- closing)))
                  (org-element-create
                   type
                   (append
                    (list :begin origin
                          :end (point)
                          :post-blank post-blank)
                    (if (memq type '(code verbatim))
                        (list :value
                              (if (fboundp 'org-element-deferred-create)
                                  (org-element-deferred-create
                                   t #'org-element--substring
                                   (- contents-begin origin)
                                   (- contents-end origin))
                                (buffer-substring-no-properties
                                 contents-begin contents-end)))
                      (list :contents-begin contents-begin
                            :contents-end contents-end)))))))))))))
