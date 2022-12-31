(in-package #:cl-user)
(ql:quickload '(cl-csv))

(defun question-type (text)
  (flet ((have (sub)
           (search sub text :test #'char-equal)))
    (cond ((have "credits")
           (cond ((have "message") :message)
                 ((have "name") :name)))
          ((have "discord") :discord)
          ((have "dweller") :dweller))))

(defun open-csv (file)
  (with-open-file (stream file)
    (cl-csv:read-csv stream)))

(defun trim (value)
  (string-trim '(#\Space #\Linefeed #\Tab) (remove #\Return value)))

(defun process-freeform (file)
  (destructuring-bind (fields . rows) (open-csv file)
    (let ((backers (make-hash-table :test 'eql)))
      (dolist (row rows)
        (flet ((field (name)
                 (nth (position name fields :test #'equalp) row)))
          (let ((id (parse-integer (field "backer_id")))
                (type (question-type (field "question_text"))))
            (setf (getf (gethash id backers) :id) id)
            (if type
                (setf (getf (gethash id backers) type)
                      (trim (field "answer_text")))
                (warn "Unknown question type: ~a" (field "question_text"))))))
      backers)))

(defun process-rewards (file)
  (destructuring-bind (fields . rows) (open-csv file)
    (let ((backers (make-hash-table :test 'eql))
          (rewards (nthcdr (position "Total Spent" fields :test #'string-equal) fields)))
      (dolist (row rows)
        (flet ((field (name)
                 (nth (position name fields :test #'equalp) row)))
          (let ((id (parse-integer (field "Id"))))
            (setf (gethash id backers) (list :rewards (loop for field in rewards
                                                            when (string= "1" (field field))
                                                            collect field)
                                             :email (field "Email"))))))
      backers)))

(defun compile-credits (file)
  (let ((data (sort (alexandria:hash-table-values (process-freeform file)) #'string<
                    :key (lambda (a) (string-downcase (getf a :name))))))
    (dolist (user data)
      (when (or (getf user :name) (getf user :message))
        (format T "~a~@[ — ~a~]~%" (or (getf user :name) "Anonymous") (getf user :message))))))

(defun compile-dwellers (file)
  (sort (loop for user being the hash-values of (process-freeform file)
              for dweller = (getf user :dweller)
              when dweller collect dweller)
        #'string<))

(defvar *reward-role-map* '(("backer-discord-role" "supporter")
                            ("beta-tester-discord-role" "hunter")))

(defun clean-discord-name (name)
  (destructuring-bind (name &optional tag) (uiop:split-string name :separator "#")
    (format NIL "~a~@[#~a~]" (string-left-trim "@" (trim name)) (when tag (trim tag)))))

(defun compile-discord (tag-file rewards-file)
  (let ((rewards (process-rewards rewards-file)))
    (loop for user being the hash-values of (process-freeform tag-file)
          for discord = (getf user :discord)
          for roles = (loop for reward in (getf (gethash (getf user :id) rewards) :rewards)
                            for role = (second (assoc reward *reward-role-map* :test #'string-equal))
                            when role collect role)
          do (when (and discord roles)
               (format T "~s~{,~s~}~%" (clean-discord-name discord) roles)))))

(defun emails-for-rewards (rewards-file rewards &key not)
  (loop for user being the hash-values of (process-rewards rewards-file)
        for have = (getf user :rewards)
        when (and (loop for reward in rewards always (find reward have :test #'string-equal))
                  (loop for reward in not never (find reward have :test #'string-equal)))
        collect (getf user :email)))
