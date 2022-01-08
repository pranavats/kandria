(in-package #:org.shirakumo.fraf.kandria)

(defclass upgrade-checkbox (alloy:checkbox)
  ((materials :initarg :materials :accessor materials)))

(defmethod alloy:active-p ((checkbox upgrade-checkbox))
  (<= (alloy:on-value checkbox) (alloy:value checkbox)))

(defmethod alloy:activate ((checkbox upgrade-checkbox))
  (let ((player (unit 'player T)))
    (when (= (1+ (sword-level player)) (alloy:on-value checkbox))
      (cond ((loop for (count item) in (materials checkbox)
                   always (<= count (item-count item player)))
             (loop for (count item) in (materials checkbox)
                   do (retrieve item player count))
             (call-next-method))
            (T
             (alloy:with-unit-parent checkbox
               (animation:apply-animation 'upgrade-not-fulfilled
                                          (presentations:find-shape 'requirements checkbox)))
             (harmony:play (// 'sound 'ui-error) :reset T))))))

(presentations:define-realization (ui upgrade-checkbox T)
  ((level simple:text)
   (alloy:extent (alloy:pw -1) (alloy:ph 1.11) (alloy:pw 3) 30)
   (@formats 'upgrade-ui-level (alloy:on-value alloy:renderable))
   :pattern colors:white
   :font (setting :display :font)
   :size (alloy:un 20)
   :halign :middle
   :valign :middle)
  ((requirements simple:text)
   (alloy:extent (alloy:pw 4) (alloy:ph -3) 500 (alloy:ph 5))
   (@formats 'upgrade-ui-requirements
             (loop for (count item) in (materials alloy:renderable)
                   collect (list count (language-string item))))
   :pattern colors:white
   :font (setting :display :font)
   :size (alloy:un 15)
   :valign :top
   :halign :left)
  ((indicator simple:line-strip)
   (vector (alloy:point (alloy:pw 1.2) (alloy:ph 0.5))
           (alloy:point (alloy:pw 3.8) (alloy:ph 1.5))
           (alloy:point (alloy:pw 3.8) (alloy:ph 2.0)))
   :pattern colors:white
   :line-width (alloy:un 2)))

(presentations:define-update (ui upgrade-checkbox)
  (level)
  (requirements
   :pattern (if alloy:focus colors:white colors:transparent))
  (indicator
   :pattern (if alloy:focus colors:white colors:transparent)))

(presentations:define-animated-shapes upgrade-checkbox
  (requirements (simple:pattern :duration 0.2))
  (indicator (simple:pattern :duration 0.2)))

(animation:define-animation upgrade-not-fulfilled
  0.1 ((setf simple:pattern) colors:red)
  0.5 ((setf simple:pattern) colors:white))

(defclass upgrade-ui (menuing-panel pausing-panel)
  ())

(defmethod initialize-instance :after ((panel upgrade-ui) &key)
  (let* ((player (unit 'player T))
         (layout (make-instance 'eating-constraint-layout
                                :shapes (list (simple:rectangle (unit 'ui-pass T) (alloy:margins) :pattern (colored:color 0 0 0 0.5)))))
         (data (make-instance 'alloy:accessor-data :object player :accessor 'sword-level))
         (focus (make-instance 'alloy:focus-list)))
    (loop for (level x y . materials) in
          '((1 150 600 (1 item:rusted-clump) (50 item:parts))
            (2 200 500)
            (3 175 400)
            (4 150 300)
            (5 200 200))
          for box = (alloy:represent-with 'upgrade-checkbox data :on level :materials materials)
          do (alloy:enter box focus)
             (alloy:enter box layout :constraints `((:left ,x) (:bottom ,y) (:size 50 50))))
    (alloy:enter (make-instance 'label :value (@ upgrade-ui-title)) layout :constraints `((:left 50) (:top 40) (:size 500 50)))
    (let ((back (make-instance 'button :value (@ go-backwards-in-ui) :on-activate (lambda () (hide panel)))))
      (alloy:enter back layout :constraints `((:left 50) (:bottom 40) (:size 200 50)))
      (alloy:enter back focus)
      (alloy:on alloy:exit (focus)
        (setf (alloy:focus back) :strong)))
    (alloy:finish-structure panel layout focus)))

