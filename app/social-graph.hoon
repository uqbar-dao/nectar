/+  verb, dbug, default-agent,  io=agentio,
    g=social-graph, *mip
|%
::
::  %social-graph agent state
::
+$  state-0
  $:  %0
      graph=social-graph:g
      perms=(map app:g permission-level:g)
      trackers=(map app:g (jug tag:g dock))  ::  docks who are tracking us
      tracking=(map [app:g tag:g] @p)        ::  tags we're tracking from others
  ==
+$  card  card:agent:gall
::
::  scry paths
::
::  /controller/[app]/[tag]  <-  returns @p of who we source a tag from
::  /nodes/[app]/[from-node]/[tag]  <-  returns (set node)
::  TODO /edge/[from-node]/[to-node]     <-  returns (unit edge)
::  TODO /app/[app]/[from-node]/[to-node]      <-  returns (unit (set tag))
::  TODO /has-tag/[app]/[from-node]/[to-node]/[tag]        <-  returns ?
::  TODO /bidirectional/[app]/[from-node]/[to-node]/[tag]  <-  returns ?
--
::
^-  agent:gall
%+  verb  |
%-  agent:dbug
=|  state=state-0
=<  |_  =bowl:gall
    +*  this  .
        hc    ~(. +> bowl)
        def   ~(. (default-agent this %|) bowl)
    ::
    ++  on-init  `this(state [%0 *social-graph:g ~ ~ ~])
    ::
    ++  on-save  !>(state)
    ::
    ++  on-load
      |=  old=vase
      ^-  (quip card _this)
      ::  nuke our state if it's of an unsupported version
      ::  note that table schemas can change without causing a state change
      ?+  -.q.old  on-init
        %0  `this(state !<(state-0 old))
      ==
    ::
    ++  on-poke
      |=  [=mark =vase]
      ^-  (quip card _this)
      =^  cards  state
        ?+  mark  (on-poke:def mark vase)
          %social-graph-edit    (handle-edit:hc !<(edit:g vase))
          %social-graph-track   (handle-tracker:hc !<(track:g vase))
          %social-graph-update  (handle-update:hc !<(update:g vase))
        ==
      [cards this]
    ::
    ++  on-peek   handle-scry:hc
    ::
    ++  on-agent
      |=  [=wire =sign:agent:gall]
      ^-  (quip card _this)
      ?+    wire  `this
          [%give-update @ @ ^]
        ::  /give-update/[app]/[q.dock]/[tag]
        ?.  ?=(%poke-ack -.sign)  `this
        ?~  p.sign  `this
        ::  if we've received a nack from an update poke,
        ::  remove that tracker so we don't keep poking them?
        ::  they might have stopped tracking off us without
        ::  giving a %leave poke...
        =/  =app:g  `@tas`i.t.wire
        =/  =dock  [src.bowl `@tas`i.t.t.wire]
        =/  =tag:g
          ?:  ?=([@ ~] t.t.t.wire)
            `@t`i.t.t.t.wire
          t.t.t.wire
        ::  hideous, i know
        =+  (~(del in (~(gut by (~(gut by trackers.state) app ~)) tag ~)) dock)
        =+  (~(put by (~(gut by trackers.state) app ~)) tag `(set ^dock)`-)
        `this(trackers.state (~(put by trackers.state) app -))
      ==
    ::
    ++  on-watch  on-watch:def
    ++  on-arvo   on-arvo:def
    ++  on-leave  on-leave:def
    ++  on-fail   on-fail:def
    --
::
|_  bowl=bowl:gall
  ++  handle-edit
    |=  =edit:g
    ^-  (quip card _state)
    ?>  =(our src):bowl
    ::  need this info in bowl for perms
    =/  =app:g  p.edit
    ?:  ?=(%start-tracking -.q.edit)
      ::  we want to sync a tag from another ship's app
      ::  note this will wipe our own representation of this tag
      :_  state(tracking (~(put by tracking.state) [[app tag] source]:q.edit))
      :_  ~
      %+  ~(poke pass:io /start-tracking)
        [source.q.edit %social-graph]
      social-graph-track+!>(`track:g`[%social-graph [%fetch [app tag]:q.edit]])
    ?:  ?=(%stop-tracking -.q.edit)
      ::  we want to STOP syncing a tag from another ship's app
      :_  state(tracking (~(del by tracking.state) [app tag]:q.edit))
      :_  ~
      %+  ~(poke pass:io /start-tracking)
        [source.q.edit %social-graph]
      social-graph-track+!>(`track:g`[%social-graph [%leave [app tag]:q.edit]])
    ::
    ?:  ?=(%set-perms -.q.edit)
      ::  we want to adjust who can sync tags from us for a given app
      ::  if permission level gets stricter, boot trackers if needed.
      =.  trackers.state
        ?-    level.q.edit
            %public   trackers.state
            %private  (~(del by trackers.state) app)
            %only-tagged
          ::  reassemble trackers by going through each tracker ship
          ::  and asserting that they fall within their specific tag
          ::  this is an expensive operation, try to avoid
          =/  my-trackers=(jug tag:g dock)  (~(gut by trackers.state) app ~)
          =/  my-app=(map tag:g nodeset:g)  (~(gut by edges.graph.state) app ~)
          %+  ~(put by trackers.state)  app
          %-  ~(urn by my-trackers)
          |=  [k=tag:g v=(set dock)]
          %-  ~(gas in *(set dock))
          %+  skim  ~(tap in v)
          |=  [p=@p term]
          (in-nodeset:g [%ship p] (~(gut by my-app) k ~))
        ==
      `state(perms (~(put by perms.state) app level.q.edit))
    ::
    ::  after add/del/nuke tags, notify all trackers
    ::
    =^  update  graph.state
      ?-  -.q.edit
        ::  type refinement in hoon is broken.
          %add-tag
        :-  [app tag.q.edit]^[%new-tag [from to]:q.edit]
        (~(add-tag sg:g graph.state) from.q.edit to.q.edit app tag.q.edit)
          %del-tag
        :-  [app tag.q.edit]^[%gone-tag [from to]:q.edit]
        (~(del-tag sg:g graph.state) from.q.edit to.q.edit app tag.q.edit)
          %nuke-tag
        :-  [app tag.q.edit]^[%all ~]
        (~(nuke-tag sg:g graph.state) app tag.q.edit)
      ==
    ::  if a deleted tag is of a tracker, must remove that tracker
    =?    trackers.state
        ?=(%del-tag -.q.edit)
      =/  =nodeset:g  (~(get-nodeset sg:g graph.state) app tag.q.edit)
      =/  tag-jug=(jug tag:g dock)  (~(gut by trackers.state) app ~)
      =-  %+  ~(put by trackers.state)  app
          (~(put by tag-jug) tag.q.edit -)
      ::  replacing entire set of docks at tag!
      %-  ~(gas in *(set dock))
      %+  skip  ~(tap in (~(gut by tag-jug) tag.q.edit ~))
      |=  =dock
      ?.  ?|  &(?=(%ship -.from.q.edit) =(p.dock +.from.q.edit))
              &(?=(%ship -.to.q.edit) =(p.dock +.to.q.edit))
          ==
        ::  this dock is not involved in del, no need
        %.n
      ::  this dock *was* involved, make sure it's still in nodeset
      !(in-nodeset:g [%ship p.dock] nodeset)
    ::
    =/  docks=(set dock)
      %+  ~(gut by (~(gut by trackers.state) app ~))
        ::  hoon type refinement is BROKEN BROKEN BROKEN LOL
        ?-  -.q.edit
          %add-tag   tag.q.edit
          %del-tag   tag.q.edit
          %nuke-tag  tag.q.edit
        ==
      ~
    :_  state
    %+  turn  ~(tap in docks)
    |=  =dock
    =/  =path
      ?:  ?=(@t -.+.q.edit)
        /give-update/[app]/[q.dock]/[-.+.q.edit]
      [%give-update app q.dock -.+.q.edit]
    %+  ~(poke pass:io path)
    dock  social-graph-update+!>(`update:g`update)
  ::
  ++  handle-tracker
    |=  =track:g
    ^-  (quip card _state)
    ::  assert that request fits permissions
    ?>  ?-  (~(gut by perms.state) app.q.track *permission-level:g)
          %private  =(src our):bowl
          %public   %.y
            %only-tagged
          ::  src.bowl must appear in nodeset under this app+tag
          =/  =nodeset:g  (~(get-nodeset sg:g graph.state) [app tag]:q.track)
          ?:  (~(has by nodeset) [%ship src.bowl])  %.y
          %-  ~(any by nodeset)
          |=  n=(set node:g)
          (~(has in n) [%ship src.bowl])
        ==
    =/  =dock  [src.bowl p.track]
    =,  q.track
    ?-    -.q.track
        %fetch
      ::  give me current state of nodeset at this app+tag,
      ::  AND give future updates
      =+  (~(put ju (~(gut by trackers.state) app ~)) tag dock)
      :_  state(trackers (~(put by trackers.state) app -))
      :_  ~
      =/  =path
        ?:  ?=(@t tag.q.track)
          /give-update/[app]/[q.dock]/[tag.q.track]
        [%give-update app q.dock tag.q.track]
      %+  ~(poke pass:io path)  dock
      =+  (~(get-nodeset sg:g graph.state) app tag)
      social-graph-update+!>(`update:g`[app tag]^[%all -])
    ::
        %track
      ::  give me future updates of nodeset at this app+tag
      =+  (~(put ju (~(gut by trackers.state) app ~)) tag dock)
      `state(trackers (~(put by trackers.state) app -))
    ::
        %leave
       ::  don't give me any more updates of nodeset at this app+tag
      =+  (~(del ju (~(gut by trackers.state) app ~)) tag dock)
      `state(trackers (~(put by trackers.state) app -))
    ==
  ::
  ::  receive an update from someone else's social graph and integrate
  ::  it into our own.
  ::
  ++  handle-update
    |=  =update:g
    ^-  (quip card _state)
    ::  first assert that we are actually tracking updates from them
    ::  their update may *only* modify the app+tag we're tracking
    ?>  =(src.bowl (~(got by tracking.state) p.update))
    ::  incorporate update into our personal graph
    ::  and don't forget to forward the update to those
    ::  who might be tracking from *us*!
    =.  graph.state
      ?-  -.q.update
          %all
        (~(replace-nodeset sg:g graph.state) nodeset.q.update p.update)
      ::
          %new-tag
        (~(add-tag sg:g graph.state) from.q.update to.q.update p.update)
      ::
          %gone-tag
        (~(del-tag sg:g graph.state) from.q.update to.q.update p.update)
      ==
    =/  docks=(set dock)
      (~(gut by (~(gut by trackers.state) app.p.update ~)) tag.p.update ~)
    :_  state
    %+  murn  ~(tap in docks)
    |=  =dock
    =/  =path
      ?:  ?=(@t tag.p.update)
        /give-update/[app.p.update]/[q.dock]/[tag.p.update]
      [%give-update app.p.update q.dock tag.p.update]
    ::  don't get caught in infinite loops!
    ?:  =([our.bowl %social-graph] dock)  ~
    :-  ~
    %+  ~(poke pass:io path)  dock
    social-graph-update+!>(`update:g`update)
  ::
  ++  handle-scry
    |=  =path
    ^-  (unit (unit cage))
    ?+    path
      ~|("unexpected scry into {<dap.bowl>} on path {<path>}" !!)
        [%x %is-installed ~]
      ``json+!>(`json`[%b &])
        [%x %controller @ ^]
      ::  /controller/[app]/[tag]
      =/  =app:g  `@tas`i.t.t.path
      =/  =tag:g
        ?:  ?=([@ ~] t.t.t.path)
          `@t`i.t.t.t.path
        t.t.t.path
      =+  (~(gut by tracking.state) [app tag] our.bowl)
      ``social-graph-result+!>(`graph-result:g`[%controller -])
    ::
        [%x %nodes @ @ @ ^]
      ::  /nodes/[app]/[from-node]/[tag]
      =/  =app:g  `@tas`i.t.t.path
      =/  =node:g
        =+  `@tas`i.t.t.t.path
        ?+  -  !!
          %ship     [- (slav %p i.t.t.t.t.path)]
          %address  [- (slav %ux i.t.t.t.t.path)]
          %entity   [- `@tas`i.t.t.t.t.path]
        ==
      =/  =tag:g
        ?:  ?=([@ ~] t.t.t.t.t.path)
          `@t`i.t.t.t.t.t.path
        t.t.t.t.t.path
      =+  (~(get-nodes sg:g graph.state) node app `tag)
      ``social-graph-result+!>(`graph-result:g`[%nodes -])
    ::
        [%x %nodes @ @ @ ~]
      ::  /nodes/[app]/[from-node]
      =/  =app:g  `@tas`i.t.t.path
      =/  =node:g
        =+  `@tas`i.t.t.t.path
        ?+  -  !!
          %ship     [- (slav %p i.t.t.t.t.path)]
          %address  [- (slav %ux i.t.t.t.t.path)]
          %entity   [- `@tas`i.t.t.t.t.path]
        ==
      =+  (~(get-nodes sg:g graph.state) node app ~)
      ``social-graph-result+!>(`graph-result:g`[%nodes -])
    ==
--