;; -*- mode: poly-dialog; -*-
(in-package #:org.shirakumo.fraf.kandria)

(define-sequence-quest (kandria demo-intro)
  :author "Tim White"
  :title "Find the Control Room"
  :description "I think I found the Semi Sisters. The one that seemed in charge said I should talk to her sister in the control room, about what I can do in exchange for her turning the water back on."
  (:interact (islay)
   :title "Find the sister in the control room"
  "
~ islay
| Hello, Stranger. It's an honour to meet you. I'm \"Islay\"(yellow).
! eval (setf (nametag (unit 'islay)) (@ islay-nametag))
~ islay
| (:unhappy)I'm sorry about my sister.
~ player
- What do I need to do?
  ~ islay
  | Right, yes. The sooner we get started, the sooner \"Innis\"(yellow) will turn your water back on.
  ! eval (setf (nametag (unit 'innis)) (@ innis-nametag))
- What's her problem?
  ~ islay
  | How long have you got? Let's just say diplomacy isn't one of \"Innis'\"(yellow) strengths.
  ! eval (setf (nametag (unit 'innis)) (@ innis-nametag))
  | She's right about the water though - we need it too.
  | But a trade is acceptable. And the sooner we get started, the sooner she'll turn it back on for you.
- Can't you just turn the water back on?
  ~ islay
  | I'm afraid not. Much as I sympathise with your predicament.
  | \"Innis\"(yellow) is at least right about that - we need that water too.
  ! eval (setf (nametag (unit 'innis)) (@ innis-nametag))
  | But a trade is acceptable. And the sooner we get started, the sooner she'll turn it back on for you.
~ islay
| Basically we've got \"rail engineers stuck\"(orange) after a tunnel collapse in the \"far high west\"(orange).
| And \"4 of our CCTV cameras on the distant low eastern\"(orange) \"Cerebat\"(red) border have gone down.
? (not (active-p (unit 'blocker-engineers)))
| ~ islay
| | Actually, no: don't worry about the engineers.
| | The last report shows they've been freed - by whom I'm not sure.
| ~ player
| - It was me.
|   < thank-you
| - Your guardian angel.
|   ~ islay
|   | Wait - are you saying...?
|   ~ player
|   - Yes.
|     < thank-you
|   - No.
|     ~ islay
|     | (:unhappy)Oh, okay then. Anyway...
|     < metro
|   - I'm not saying anything.
|     ~ islay
|     | (:unhappy)Oh, okay. Anyway...
|     < metro
| - Who do you think?
|   < thank-you
! label questions
~ player
- [(active-p (unit 'blocker-engineers)) Tell me about the trapped engineers.|]
  ~ islay
  | There were ten of them, working in the \"far high west of our territory\"(orange).
  | We're slowly digging out the old maglev metro system. We've got a basic electrified railway going.
  | (:unhappy)But it's dangerous work. They didn't report in, and our hunters found the tunnel collapsed.
  < questions
- [(not (active-p (unit 'blocker-engineers))) So the engineers were working on the metro?|]
  ~ islay
  | Correct. We're slowly digging out the old maglev system. We've got a basic electrified railway going.
  | But it's dangerous work.
  < questions
- Tell me about the down CCTV cameras.
  ~ islay
  | We monitor the surrounding areas, immediately above and below.
  | But \"4 of our cameras\"(orange) on the Cerebat border have gone down, in the \"distant low eastern region\"(orange).
  | It's probably just an electrical fault. Unfortunately the way we daisy-chain them together, when one goes they all go.
  | I'd like you to \"check them out\"(orange).
  < questions
- Understood.
~ islay
| We've seen what you can do - you're better suited to this than even our hunters.
| (:nervous)Just don't tell Innis I said that. She'll think I've gone soft for androids.
| (:normal)I can also \"trade any items you find for scrap parts\"(orange), the currency we use around here.
| Then you can \"buy supplies\"(orange) to help you in the field.
| \"Let me know if you want to trade.\"(orange)
| \"Report to Innis\"(orange) when you have news - by then she should be \"back here in the control room\"(orange).
| Good luck.
! eval (activate 'demo-cctv)
! eval (activate (unit 'cctv-4-trigger))
? (active-p (unit 'blocker-engineers))
| ! eval (activate 'demo-engineers)
| ! eval (deactivate (find-task 'world 'task-world-engineers))
| ! eval (deactivate (find-task 'world 'task-engineers-wall-listen))
|?
| ! eval (complete 'demo-engineers)

# thank-you
~ islay
| Really? You did that for us?
~ player
- Sure.
- That's what I do.
- I was exploring, so figured why not.
~ islay
| Well in that case, thank you. We owe you.
| But there's more to do.
< metro

# metro
~ islay
| This does mean our engineering works are back on schedule though.
| With that in mind, I think we could grant you \"access to the metro\"(orange).
| It will certainly \"speed up your errands - once you've found the other stations\"(orange).
? (or (unlocked-p (unit 'station-surface)) (unlocked-p (unit 'station-semi-sisters)))
| | We know you know about the metro already, and that's alright. But now it's official.
| | I'll send out word, so Innis won't have you... (:nervous)apprehended.
| | (:normal)\"The stations run throughout the valley\"(orange). Though \"not all are operational\"(orange) while we expand the network.
|?
| | (:normal)\"They run throughout the valley\"(orange), though \"not all are operational\"(orange) while we expand the network.
| | Just \"choose your destination from the route map\"(orange) and board the train.
? (not (unlocked-p (unit 'station-semi-sisters)))
| | (:normal)\"Our station is beneath this central block.\"(orange)
| ! eval (activate 'semi-station-marker)
|?
| ! eval (complete 'semi-station-marker)
< questions
")
  (:eval
   :condition (not (find-panel 'fullscreen-prompt))
   (fullscreen-prompt 'toggle-menu))
  (:eval
   :condition (not (find-panel 'fullscreen-prompt))
   (fullscreen-prompt 'interact :title 'save-demo))
  (:eval
   :on-complete (trader-shop-semi)
   (setf (music-state 'region1) :quiet)))
