define (require) ->

  ###*
  # ツールチップモジュール
  #
  # ツールチップ内容：data-tooltip-title属性か、data-tooltip-img属性、.js-tooltip-content（どちらか必須）
  # ツールチップタイプ：data-tooltip-type属性（必須）
  # ツールチップサイズ：data-tooltip-size属性（非必須）
  # コピペ可能か： data-copyable属性（非必須）
  #
  # 初期化のやり方： $(document).customtooltip()
  #
  # @class tooltip
  ###
  $.widget "customtooltip",
    _positionOptions:
      tl:
        my: 'left bottom-5',
        at: 'left top'
      t:
        my: 'center bottom-5'
        at: 'center top'
      tr:
        my: 'right bottom-5'
        at: 'right top'
      r:
        my: 'left+5 center'
        at: 'right center'
      l:
        my: 'right-5 center'
        at: 'left center'
      bl:
        my: 'left top+5'
        at: 'left bottom'
      b:
        my: 'center top+5'
        at: 'center bottom'
      br:
        my: 'right top+5'
        at: 'right bottom'

    options:
      content: ->
        $this = $(@)

        if $this.data 'tooltip-title'
          content = $this.data 'tooltip-title'
          return $('<div>').text content
        if $this.data 'tooltip-img'
          content = $('<img class="js-tooltip-img">').attr 'src', $this.data 'tooltip-img'
          return $('<div>').append content
        else
          content = $this.find('.js-tooltip-content:eq(0)').html()
          return $('<div>').html content

      ###*
      # Tooltip要素に付けるクラス
      #
      # @property options.tooltipClass
      # @type {String}
      # @default 'm-tooltip'
      ###
      tooltipClass: 'm-tooltip'

      ###*
      # Tooltipの出現位置
      #
      # @property options.position
      # @type {Object}
      # @default {my: 'left bottom-5', at: 'left top'}
      ###
      position:
        my: 'left bottom-5',
        at: 'left top'

      ###*
      # Tooltipトリガーとなる要素のセレクタ
      #
      # @property options.items
      # @type {String}
      # @default '[data-tooltip-type]:not([disabled])'
      ###
      items: '[data-tooltip-type]:not([disabled])'

      ###*
      # Tooltipの出現エフェクト
      #
      # @property options.show
      # @type {Object}
      # @default {effect: 'fadeIn', duration: 100}
      ###
      show:
        effect: 'fadeIn'
        duration: 100

      ###*
      # Tooltipの消失エフェクト
      #
      # @property options.hide
      # @type {Object}
      # @default {effect: 'fadeOut', duration: 100}
      ###
      hide:
        effect: 'fadeOut'
        duration: 100

      track: false

      # callbacks
      close: null
      open: null

    _addTooltipId: (elem, id)->
      elem.data "ui-tooltip-id", id

    _removeTooltipId: (elem)->
      elem.removeData "ui-tooltip-id"

    _create: ->
      @_on
        mouseover: "open"
        focusin: "open"

      # IDs of generated tooltips, needed for destroy
      @tooltips = {}
      # IDs of parent tooltips where we removed the title attribute
      @parents = {}

      @_disable() if @options.disabled

      # Append the aria-live region so tooltips announce correctly
      @liveRegion = $ "<div>"
        .addClass "ui-helper-hidden-accessible"
        .appendTo @document[0].body

    _setOption: (key, value)->
      that = @

      if key is "disabled"
        @[if value then "_disable" else "_enable"]()
        @options[key] = value
        return

      @_super key, value

      if key is "content"
        $.each @tooltips, (id, element)->
          that._updateContent element

    _disable: ->
      that = @

      # close open tooltips
      $.each @tooltips, (id, element)->
        event = $.Event "blur"
        event.target = event.currentTarget = element[0]
        that.close event, true

    _enable: $.noop,

    ###*
    # Tooltip要素のDOMを生成し、表示させる
    #
    # @method open
    # @param e {Object} Event Object
    ###
    open: (event)->
      that = @
      target = $(if event then event.target else @element)
        # we need closest here due to mouseover bubbling,
        # but always pointing at the same event target
        .closest @options.items

      # No element to show a tooltip for or the tooltip is already open
      return if !target.length or target.data "ui-tooltip-id"

      target.data "ui-tooltip-open", true

      # kill parent tooltips, custom or native, for hover
      if event and event.type is "mouseover"
        target.parents().each ->
          parent = $ @
          blurEvent = undefined

          if parent.data "ui-tooltip-open"
            blurEvent = $.Event "blur"
            blurEvent.target = blurEvent.currentTarget = @
            that.close blurEvent, true

          if parent.data "tooltip-title"
            parent.uniqueId()
            that.parents[@id] =
              element: @
              title: parent.data "tooltip-title"

      @_updateContent target, event

    _updateContent: (target, event)->
      position = target.data('tooltip-pos')
      position = position.toLowerCase() if position
      if position of @_positionOptions
        @option 'position', @_positionOptions[position]
      else
        @option 'position', @_positionOptions['tl']

      type = target.data('tooltip-type')
      @option 'type', type or ''

      size = target.data('tooltip-size')
      @option 'size', size or ''

      content = undefined
      contentOption = @options.content
      that = @
      eventType = if event then event.type else null

      if typeof contentOption is "string"
        return @_open event, target, contentOption

      content = contentOption.call target[0], (response)->
        # ignore async response if tooltip was closed already
        return unless target.data "ui-tooltip-open"

        # IE may instantly serve a cached response for ajax requests
        # delay this call to _open so the other call to _open runs first
        that._delay ->
          # jQuery creates a special event for focusin when it doesn't
          # exist natively. To improve performance, the native event
          # object is reused and the type is changed. Therefore, we can't
          # rely on the type being correct after the event finished
          # bubbling, so we set it back to the previous value. (#8740)
          event.type = eventType if event
          @_open event, target, response

      @_open event, target, content if content

    _open: (event, target, content)->
      tooltip = undefined
      events = undefined
      delayedShow = undefined
      a11yContent = undefined
      positionOption = $.extend {}, @options.position

      return unless content

      # Content can be updated multiple times. If the tooltip already
      # exists, then just update the content and bail.
      tooltip = @_find target
      if tooltip.length
        tooltip.find(".ui-tooltip-content").html content
        return

      tooltip = @_tooltip target
      @_addTooltipId target, tooltip.attr "id"
      tooltip.find(".ui-tooltip-content").html content

      position = (event)->
        positionOption.of = event
        return if tooltip.is ":hidden"
        tooltip.position positionOption

      if @options.track and event and /^mouse/.test event.type
        @_on @document,
          mousemove: position

        # trigger once to override element-relative positioning
        position event
      else
        tooltip.position $.extend({of: target}, @options.position)

      tooltip.hide()

      @_show tooltip, @options.show
      # Handle tracking tooltips that are shown with a delay (#8644). As soon
      # as the tooltip is visible, position the tooltip using the most recent
      # event.
      if @options.show and @options.show.delay
        delayedShow = @delayedShow = setInterval ->
          if tooltip.is ":visible"
            position positionOption.of
            clearInterval delayedShow
        , $.fx.interval

      @_trigger "open", event, {tooltip: tooltip}

      events =
        keyup: (event)->
          if event.keyCode is $.ui.keyCode.ESCAPE
            fakeEvent = $.Event event
            fakeEvent.currentTarget = target[0]
            @_close fakeEvent, true

      # Only bind remove handler for delegated targets. Non-delegated
      # tooltips will handle this in destroy.
      if target[0] isnt @element[0]
        events.remove = -> @_removeTooltip tooltip

      if !event or event.type is "mouseover"
        events.mouseleave = "close"

      if !event or event.type is "focusin"
        events.focusout = "close"

      @_on true, target, events

    ###*
    # Tooltipを閉じると、500msの間触られなかったら、消えるだけ
    # マウスオンしなければ、消えずに表示
    #
    # @method close
    # @param e {Object} Event Object
    ###
    close: (event)->
      target = $(if event then event.currentTarget else @element)
      tooltip = @_find target

      _close = _.bind @_close, @, event

      if target.data 'copyable'
        # ツールチップを消すまで猶予を持たせる
        closeTooltipTimer = @_delay _close, 500

        # 猶予の間にツールチップにカーソルを重ねたら、そのまま消えずに表示、離れるとまた消える
        tooltip.hover ->
          clearTimeout closeTooltipTimer
          return
        , ->
          _close()
          return
      else
        _close()

      return

    _close: (event)->
      that = @
      target = $(if event then event.currentTarget else @element)
      tooltip = @_find target

      # disabling closes the tooltip, so we need to track when we're closing
      # to avoid an infinite loop in case the tooltip becomes disabled on close
      return if @closing

      # Clear the interval for delayed tracking tooltips
      clearInterval @delayedShow

      @_removeTooltipId target

      tooltip.stop true
      @_hide tooltip, @options.hide, ->
        that._removeTooltip $(@)

        _.each that.tooltips, (obj, key) ->
          item = that._find obj
          if tooltip.css('top') is item.css('top') and tooltip.css('left') is item.css('left')
            that._removeTooltip item

      target.removeData "ui-tooltip-open"
      @_off target, "mouseleave focusout keyup"

      # Remove 'remove' binding only on delegated targets
      @_off target, "remove" if target[0] isnt @element[0]
      @_off @document, "mousemove"

      @closing = true
      @_trigger "close", event, { tooltip: tooltip }
      @closing = false

    _tooltip: (element)->
      type = @option('type')
      size = @option('size')

      tooltip = $ "<div>"
        .addClass @options.tooltipClass or ""
        .css
          position: 'absolute'
          zIndex: 9999
        .find '.ui-tooltip-content'
          .addClass 'tooltip__item'
          .end()

      tooltip.addClass type if type
      tooltip.addClass "tooltip--#{size}" if size

      id = tooltip.uniqueId().attr "id"

      $ "<div>"
        .addClass "ui-tooltip-content"
        .appendTo tooltip

      tooltip.appendTo @document[0].body
      @tooltips[id] = element

      return tooltip

    _find: (target)->
      id = target.data "ui-tooltip-id"
      return if id then $( "#" + id ) else $()

    _removeTooltip: (tooltip)->
      tooltip.remove()
      delete @tooltips[tooltip.attr "id"]

    _destroy: ->
      that = @

      # close open tooltips
      $.each @tooltips, (id, element)->
        event = $.Event "blur"
        event.target = event.currentTarget = element[0]
        that.close event, true

        # Remove immediately; destroying an open tooltip doesn't use the
        # hide animation
        $("#" + id).remove()

      @liveRegion.remove()

  return
