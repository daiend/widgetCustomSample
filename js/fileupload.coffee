define (require) ->
  util = require 'modules/util'

  ###*
  # ファイルアップロードモジュール
  #
  # IE以外のブラウザで、ドラッグアンドドロップに対応
  #
  # 初期化のやり方：
  #
  #   $(document).fileupload()
  #
  # @class fileupload
  ###

  $.widget 'fileupload',
    options:
      ###*
      # ドラッグアンドドロップ開始時につけるクラス
      #
      # @property options.dragstartClass
      # @type {String}
      # @default 'drag'
      ###
      dragstartClass: 'drag'
      ###*
      # ドロップ可能の時につけるクラス
      #
      # @property options.dragoverClass
      # @type {String}
      # @default 'drop'
      ###
      dragoverClass: 'drop'
      ###*
      # デフォルト文言
      #
      # @property options.defaultText
      # @type {String}
      # @default 'ここにファイルのドラッグ&ドロップも可能です'
      ###
      defaultText: 'ここにファイルのドラッグ&ドロップも可能です'
      ###*
      # IEデフォルト文言
      #
      # @property options.defaultTextIE
      # @type {String}
      # @default 'ファイルを選択してください'
      ###
      defaultTextIE: 'ファイルを選択してください'
      ###*
      # ドラッグアンドドロップ開始時の文言
      #
      # @property options.dragstartText
      # @type {String}
      # @default 'ここにファイルをドラッグ&ドロップしてください'
      ###
      dragstartText: 'ここにファイルをドラッグ&ドロップしてください'
      ###*
      # ドロップ可能の時の文言
      #
      # @property options.dragoverText
      # @type {String}
      # @default 'ファイルをドロップ'
      ###
      dragoverText: 'ファイルをドロップ'
      ###*
      # 画像プレビュー用のアップロードAPI
      #
      # @property options.previewAPI
      # @type {String}
      # @default cmnData.imagePreviewAPI
      ###
      previewAPI: ()->
        return (window.cmnData && window.cmnData.imagePreviewAPI) || '/web/pc-r01/src/api/PD/imagePreview.php'

    _dragenterCount: 0

    _create: ->
      @_on
        'change .js-fileupload input[type="file"]': @onChange

      if $('body').hasClass 'ie9'
        # IEでファイルを違う文言を出す
        @element.find('.js-fileupload .js-placeholder').attr('placeholder', @option('defaultTextIE'))
      else
        # IE以外ではドラッグアンドドロップを有効に
        @_on
          'dragenter': @onDragenter
          'dragleave': @onDragleave
          'drop': @onDrop
          'cleandrag': @onCleandrag

      return

    ###*
    # プレビュー実行中なのかのフラグ
    #
    # @property _isPreviewing
    # @type Boolean
    # @private
    # @default false
    ###
    _isPreviewing: false

    ###*
    # Input[type="file"]要素の値が変更されたら、Input[type="text"]のほうに反映させる
    #
    # @method onChange
    # @param e {Object} Event Object
    ###
    onChange: (e)->
      fileinput = $(e.target)
      fileupload = fileinput.closest('.js-fileupload')
      textinput = fileupload.find('input[type="text"]')

      textinput.val fileinput.val().replace('C:\\fakepath\\', '')

      if fileinput.val() and window.File and window.FileReader
        isFileInSize = @validateFileSize fileinput
      else
        isFileInSize = true # 検証できない場合は、とりあえずtrueで

      unless isFileInSize
        fileinput
        .val ''
        .trigger 'change'

        $(document).flashmsg 'create',
          type: 'error'
          title: 'ファイルサイズの制限を超えています。'
          target: fileinput

      $(e.currentTarget).trigger 'fileInputChanged'

      previewer = $ '[data-previewer-id="' + fileupload.data('previewer') + '"]'
      if previewer.length and previewer.hasClass 'm-thumbnailBlock'
        return unless fileinput.val()

        if window.File and window.FileReader
          if isFileInSize
            @showPreview fileinput, previewer
          else
            previewer
            .find('.m-thumbnail').addClass 'disabled'
        else
          @showLegacyPreview fileinput, previewer

      return

    ###*
    # FileAPIを使って、ファイルは適合するかを判断する
    #
    # @method validateFileSize
    # @param fileinput {jQuery} File input
    # @return {Boolean} ファイルは適合するか
    ###
    validateFileSize: (fileinput)->
      file = fileinput[0].files[0]
      maxsize = fileinput.data('maxsize') * 1 or Infinity
      return file.size < maxsize

    ###*
    # FileAPIを使って、Previewer要素に画像をプレビューする
    #
    # @method showPreview
    # @param fileinput {jQuery} File input
    # @param previewer {jQuery} Previewer element
    ###
    showPreview: (fileinput, previewer)->
      # FileAPIでプレビューを出す
      file = fileinput[0].files[0]
      fileReader = new FileReader()

      filesize = util.calculateFileSize file.size
      filetype = file.type

      previewer
      .find('.m-thumbnail').removeClass('disabled').end()
      .find('img').hide().end()
      .find('.icon--loading').show().end()
      .find('.js-imagesize').text(filesize).end()
      .find('.js-imagetype').text(filetype).end()

      fileReader.onload = ->
        previewer
        .find('img').attr('src', fileReader.result).show().end()
        .find('.icon--loading').hide().end()

        @_isPreviewing = false

        return

      @_isPreviewing = true
      fileReader.readAsDataURL file

      return

    ###*
    # iframeの通信を使って、Previewer要素に画像をプレビューする
    #
    # @method showLegacyPreview
    # @param fileinput {jQuery} File input
    # @param previewer {jQuery} Previewer element
    ###
    showLegacyPreview: (fileinput, previewer)->
      promise = $.legacySjax
        url: @option 'previewAPI'
        data:
          image: fileinput

      promise.then (result)->
        filesize = util.calculateFileSize(result.filesize)
        filetype = result.filetype

        previewer
        .find('.m-thumbnail').removeClass('disabled').end()
        .find('img').hide().end()
        .find('.icon--loading').show().end()
        .find('img').attr('src', result.imageurl).show().end()
        .find('.js-imagesize').text(filesize).end()
        .find('.js-imagetype').text(filetype).end()

        previewer.find('.icon--loading').hide().end()

        @_isPreviewing = false

        return

      previewer
      .find('img').hide().end()
      .find('.icon--loading').show().end()

      @_isPreviewing = true

      return

    ###*
    # ドラッグ中に、ドラッグアンドドロップを受け入れられるの領域を表示
    #
    # @method onDragenter
    # @param e {Object} Event Object
    ###
    onDragenter: (e)->
      @_dragenterCount++
      @showDragArea() if @_dragenterCount

      input = $(e.target).closest('.js-fileupload input[type="file"]')

      if input.length
        fileupload = input.closest('.js-fileupload')
        fileuploadDragenterCount = fileupload.data('dragenterCount')
        fileuploadDragenterCount = fileuploadDragenterCount + 1 or 1

        @showDropableArea(fileupload) if fileuploadDragenterCount

        fileupload.data 'dragenterCount',  fileuploadDragenterCount

      return

    ###*
    # ドラッグ中に、現在ドロップ可能の領域を表示
    #
    # @method onDragleave
    # @param e {Object} Event Object
    ###
    onDragleave: (e)->
      @_dragenterCount--
      @hideDragArea() unless @_dragenterCount

      input = $(e.target).closest('.js-fileupload input[type="file"]')

      if input.length
        fileupload = input.closest('.js-fileupload')
        fileuploadDragenterCount = fileupload.data('dragenterCount')
        fileuploadDragenterCount = fileuploadDragenterCount - 1 or 0

        @hideDropableArea(fileupload) unless fileuploadDragenterCount

        fileupload.data 'dragenterCount',  fileuploadDragenterCount
      return

    ###*
    # ドロップしたら、ドラッグアンドドロップ領域を一旦隠す
    #
    # @method onDrop
    # @param e {Object} Event Object
    ###
    onDrop: (e)->
      fileupload = $(e.target).closest('.js-fileupload')

      # ドラッグエリアに入っていない場合
      if !fileupload.size()
        e.preventDefault()
        e.stopPropagation()

      if fileupload.length
        fileupload.data('dragenterCount', 0)
        @hideDropableArea(fileupload)

      $(document).trigger 'cleandrag'

    onDragOver: (e)->
      e.preventDefault()
    ###*
    # D&D操作が終わったので、ドラッグエリアを隠す
    #
    # @method onCleandrag
    # @param e {Object} Event Object
    ###
    onCleandrag: (e)->
      @_dragenterCount = 0
      @hideDragArea()

      return

    ###*
    # ドラッグ可能領域は表示中なのか
    #
    # @property _isDragAreaShown
    # @private
    # @type {Boolean}
    ###
    _isDragAreaShown: false


    ###*
    # ドラッグアンドドロップ受け入れられる領域を表示
    #
    # @method showDragArea
    ###
    showDragArea: ->
      return if @_isDragAreaShown

      @element.find('.js-fileupload').addClass @option('dragstartClass')

      @_isDragAreaShown = true
      return

    ###*
    # ドラッグアンドドロップ受け入れられる領域を隠す
    #
    # @method hideDragArea
    ###
    hideDragArea: ->
      return unless @_isDragAreaShown

      @element.find('.js-fileupload.' + @option('dragstartClass')).removeClass @option('dragstartClass')

      @_isDragAreaShown = false
      return

    ###*
    # 現在ドロップ可能の領域を表示、文言を変更
    #
    # @method showDropableArea
    # @param fileupload {jQuery Object} .js-fileupload要素のjQueryオブジェクト
    ###
    showDropableArea: (fileupload)->
      fileupload
      .addClass @option('dragoverClass')
      .find '.formSet__dragDrop'
      .text @option('dragoverText')

    ###*
    # 現在ドロップ可能の領域を隠す、文言を変更
    #
    # @method hideDropableArea
    # @param fileupload {jQuery Object} .js-fileupload要素のjQueryオブジェクト
    ###
    hideDropableArea: (fileupload)->
      fileupload
      .removeClass @option('dragoverClass')
      .find '.formSet__dragDrop'
      .text @option('dragstartText')

  return
