(in-package #:org.shirakumo.fraf.kandria)

(defclass map-element (alloy:renderable alloy:focus-element alloy:layout-element)
  ((offset :initform (vec 0 0) :accessor offset)
   (state :initform NIL :accessor state)
   (zoom :initform 0.15 :accessor zoom)))

(animation:define-animation (pulse-marker :loop T)
  0 ((setf simple:pattern) (colored:color 1 0 0 0.2) :easing animation:cubic-in-out)
  1 ((setf simple:pattern) (colored:color 1 0 0 0.5) :easing animation:cubic-in-out)
  2 ((setf simple:pattern) (colored:color 1 0 0 0.2) :easing animation:cubic-in-out))

(defmethod presentations:realize-renderable ((renderer presentations:renderer) (map map-element))
  (presentations:clear-shapes map)
  (let ((array (make-array 0 :adjustable T :fill-pointer T))
        (player (unit 'player T))
        (gap 10)
        (fac (alloy:to-px (alloy:un 1))))
    (setf (offset map) (v* (location player) fac))
    (flet ((unit-marker (unit color)
             (when (visible-on-map-p (chunk unit))
               (let ((bounds (alloy:extent (- (vx (location unit)) (* gap 5))
                                           (- (vy (location unit)) (* gap 5))
                                           (* gap 5 2)
                                           (* gap 5 2))))
                 (vector-push-extend (cons (name unit) (simple:rectangle renderer bounds :pattern color :name (name unit) :z-index -8)) array))))
           (target-marker (location size color)
             (let* ((bounds (alloy:extent (- (vx location) (/ size 2))
                                          (- (vy location) (/ size 2))
                                          size size))
                    (fill (colored:color (colored:r color) (colored:g color) (colored:b color) 0.5))
                    (shape (simple:ellipse renderer bounds :pattern fill :name :target :z-index -9)))
               (vector-push-extend (cons :target shape) array)
               (animation:apply-animation 'pulse-marker shape))))
      (for:for ((unit over (region +world+)))
        (typecase unit
          (chunk
           (when (and (unlocked-p unit) (visible-on-map-p unit))
             (let ((bounds (alloy:extent (+ gap (- (vx (location unit)) (vx (bsize unit))))
                                         (+ gap (- (vy (location unit)) (vy (bsize unit))))
                                         (- (* 2 (vx (bsize unit))) (* 2 gap))
                                         (- (* 2 (vy (bsize unit))) (* 2 gap)))))
               (vector-push-extend (cons (name unit) (simple:rectangle renderer bounds :pattern (colored:color 1 1 1 0.75)
                                                                                       :name (name unit)
                                                                                       :z-index -10)) array)
               (when (eql unit (chunk player))
                 (vector-push-extend (cons (name unit) (simple:rectangle renderer bounds :pattern colors:yellow
                                                                                         :name (name unit)
                                                                                         :line-width (alloy:un 4)
                                                                                         :z-index -10))
                                     array)))))
          (npc
           (unit-marker unit (colored:color 0.5 1 0.5 1))
           (when (and (eql :lead (ai-state unit))
                      (visible-on-map-p (chunk unit)))
             (target-marker (location unit) (* 40 +tile-size+) colors:red)))))
      (dolist (quest (quest:known-quests (storyline +world+)))
        (dolist (task (quest:active-tasks quest))
          (when (marker task)
            (destructuring-bind (location size &optional (color colors:red)) (enlist (marker task) (* 40 +tile-size+))
              (target-marker (ensure-location location) size color)))))
      (unit-marker player (colored:color 0.5 0.5 1 1)))
    (let ((trace (movement-trace player))
          (points (make-array 0 :adjustable T :fill-pointer T))
          (color (colored:color 0 0.8 1 0.5)))
      (flet ((flush ()
               (when (< 0 (length points))
                 (vector-push-extend (cons 'trace (simple:line-strip renderer points
                                                                     :pattern color
                                                                     :line-width (alloy:un 4)
                                                                     :hidden-p T
                                                                     :z-index -5))
                                     array)
                 (setf (fill-pointer points) 0))))
        (loop for i from 0 below (length trace) by 2
              do (cond ((float-features:float-nan-p (aref trace i))
                        (flush)
                        (when (float-features:float-infinity-p (aref trace (1+ i)))
                          (let ((bounds (alloy:extent (- (aref trace (- i 2)) 32)
                                                      (- (aref trace (- i 1)) 32)
                                                      64 64)))
                            (vector-push-extend (cons :death (simple:text renderer bounds "✗"
                                                                          :size (alloy:un 64)
                                                                          :pattern colors:red
                                                                          :valign :middle
                                                                          :halign :middle
                                                                          :name :death
                                                                          :z-index -4
                                                                          :font "PromptFont"))
                                                array))))
                       (T
                        (vector-push-extend (alloy:point (aref trace i) (aref trace (1+ i))) points)))
              finally (flush))))
    (setf (presentations:shapes map) array)))

(defmethod alloy:suggest-bounds (bounds (map map-element))
  bounds)

(defmethod alloy:render :around ((renderer alloy:renderer) (map map-element))
  (alloy:with-unit-parent map
    (when (alloy:render-needed-p map)
      (presentations:realize-renderable renderer map)
      (setf (slot-value map 'alloy:render-needed-p) NIL))
    (simple:with-pushed-transforms (renderer)
      (alloy:render renderer (simple:rectangle renderer (alloy:bounds map) :pattern (colored:color 0 0 0 0.5)))
      (simple:translate renderer (alloy:px-point (/ (width *context*) 2) (/ (height *context*) 2)))
      (simple:scale renderer (alloy:size (zoom map) (zoom map)))
      (simple:translate renderer (alloy:px-point (- (vx (offset map))) (- (vy (offset map)))))
      (loop for (name . shape) across (presentations:shapes map)
            do (unless (presentations:hidden-p shape)
                 (simple:with-pushed-transforms (renderer)
                   (setf (simple:z-index renderer) (presentations:z-index shape))
                   (alloy:render renderer shape)))))))

(defmethod alloy:handle ((ev alloy:pointer-event) (focus map-element))
  (restart-case
      (call-next-method)
    (alloy:decline ()
      T)))

(defmethod alloy:handle ((ev alloy:scroll) (panel map-element))
  (setf (zoom panel) (clamp 0.01 (+ (zoom panel) (* 0.01 (alloy:dy ev))) 0.5)))

(defmethod alloy:handle ((ev alloy:pointer-down) (panel map-element))
  (setf (state panel) :drag))

(defmethod alloy:handle ((ev alloy:pointer-up) (panel map-element))
  (setf (state panel) NIL))

(defmethod alloy:handle ((ev alloy:pointer-move) (panel map-element))
  (case (state panel)
    (:drag
     (let ((l (alloy:location ev))
           (o (alloy:old-location ev)))
       (incf (vx (offset panel)) (/ (- (alloy:pxx o) (alloy:pxx l)) (zoom panel)))
       (incf (vy (offset panel)) (/ (- (alloy:pxy o) (alloy:pxy l)) (zoom panel)))))))

(defclass map-panel (panel)
  ((show-trace :initform NIL :accessor show-trace)))

(defmethod initialize-instance :after ((panel map-panel) &key)
  (clear-retained)
  (let ((map (make-instance 'map-element))
        (off 0))
    (flet ((prompt (action)
             (alloy:enter (make-instance 'prompt :button action :description (language-string action))
                          (unit 'ui-pass T) :x (* 20 (- 4 off)) :y (+ 20 (* 50 off)) :w 200 :h 40)
             (incf off)))
      (prompt 'toggle-trace)
      (prompt 'zoom-in)
      (prompt 'zoom-out)
      (prompt 'close-map))
    (alloy:finish-structure panel map map)))

(defmethod hide :after ((panel map-panel))
  (let ((els ()))
    (alloy:do-elements (el (alloy:popups (alloy:layout-tree (unit 'ui-pass T))))
      (push el els))
    (mapc #'hide els)))

(defmethod (setf active-p) :after (value (panel map-panel))
  (if value
      (setf (active-p (action-set 'in-map)) T)
      (setf (active-p (action-set 'in-game)) T)))

(defun update-player-tick (panel x y)
  (let ((shape (presentations:find-shape 'player (alloy:focus-element panel))))
    (when shape
      (setf (alloy:unit-value (the alloy:un (alloy:x (simple:bounds shape)))) x)
      (setf (alloy:unit-value (the alloy:un (alloy:y (simple:bounds shape)))) y))))

(defmethod handle ((ev tick) (panel map-panel))
  (let ((map (alloy:focus-element panel))
        (speed 50))
    (when (show-trace panel)
      (loop for (name . shape) across (presentations:shapes map)
            do (when (eql name 'trace)
                 (let ((data (org.shirakumo.alloy.renderers.opengl::data shape))
                       (idx (* (org.shirakumo.alloy.renderers.opengl::size shape) 4 6)))
                   (when (< idx (length data))
                     (incf (org.shirakumo.alloy.renderers.opengl::size shape) 2)
                     ;; KLUDGE: extract position from line
                     (alloy:with-unit-parent (alloy:layout-element panel)
                       (when (< (+ (* 4 6) 1 idx) (length data))
                         (let* ((x (aref data (+ (* 4 6) idx)))
                                (y (aref data (+ (* 4 6) 1 idx))))
                           (unless (= 0.0 x y)
                             (update-player-tick panel (alloy:to-un x) (alloy:to-un y))))))
                     (return))))))
    (when (retained 'pan-left)
      (incf (vx (offset map)) (- speed)))
    (when (retained 'pan-right)
      (incf (vx (offset map)) (+ speed)))
    (when (retained 'pan-down)
      (incf (vy (offset map)) (- speed)))
    (when (retained 'pan-up)
      (incf (vy (offset map)) (+ speed)))
    (when (retained 'zoom-in)
      (setf (zoom map) (clamp 0.01 (+ (zoom map) 0.001) 0.5)))
    (when (retained 'zoom-out)
      (setf (zoom map) (clamp 0.01 (- (zoom map) 0.001) 0.5)))
    (let ((popups (alloy:popups (alloy:layout-tree (unit 'ui-pass T))))
          (tt (* 1.3 (tt ev)))
          (off 0))
      (alloy:with-unit-parent popups
        (alloy:do-elements (el popups)
          (let ((tt (+ tt (* off) (/ PI 13)))
                (ui-scale (alloy:to-px (alloy:un 1))))
            (alloy:update el popups :x (* ui-scale (+ (* 20 (- 4 off)) (* 5 (cos tt))))
                                    :y (* ui-scale (+ 20 (* 50 off) (* 3 (sin tt) (cos tt))))
                                    :w (* ui-scale 200)
                                    :h (* ui-scale 40))
            (incf off)))))))

(defmethod handle ((ev toggle-trace) (panel map-panel))
  (let ((map (alloy:focus-element panel)))
    (setf (show-trace panel) (ecase (show-trace panel)
                               ((NIL) :scroll)
                               (:scroll :complete)
                               (:complete NIL)))
    (when (find (show-trace panel) '(NIL :complete))
      (update-player-tick panel (vx (location (unit 'player T))) (vy (location (unit 'player T)))))
    (loop for (name . shape) across (presentations:shapes map)
          do (when (eql name 'trace)
               (ecase (show-trace panel)
                 ((NIL) (setf (org.shirakumo.alloy.renderers.opengl::size shape) 0))
                 (:scroll (setf (org.shirakumo.alloy.renderers.opengl::size shape) 0))
                 (:complete (setf (org.shirakumo.alloy.renderers.opengl::size shape) 1000000000)))
               (setf (presentations:hidden-p shape) (not (show-trace panel)))))))

(defmethod handle ((ev close-map) (panel map-panel))
  (hide panel))
