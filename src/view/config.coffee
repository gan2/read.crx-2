app.boot "/view/config.html", ["cache", "bbsmenu"], (Cache, BBSMenu) ->
  $view = $(document.documentElement)

  app.view_module.view($view)

  #閉じるボタン
  $view.find(".button_close").bind "click", ->
    if frameElement
      tmp = type: "request_killme"
      parent.postMessage(JSON.stringify(tmp), location.origin)
    return

  #汎用設定項目
  $view
    .find("input.direct[type=\"text\"], textarea.direct")
      .each ->
        this.value = app.config.get(this.name) or ""
        null
      .bind "input", ->
        app.config.set(this.name, this.value)
        return

  $view
    .find("input.direct[type=\"checkbox\"]")
      .each ->
        this.checked = app.config.get(this.name) is "on"
        null
      .bind "change", ->
        app.config.set(this.name, if this.checked then "on" else "off")
        return

  $view
    .find("input.direct[type=\"radio\"]")
      .each ->
        if this.value is app.config.get(this.name)
          this.checked = true
        return
      .bind "change", ->
        val = $view.find("""input[name="#{this.name}"]:checked""").val()
        app.config.set(this.name, val)
        return

  #バージョン情報表示
  $view.find(".version_text")
    .text("#{app.manifest.name} v#{app.manifest.version} + #{navigator.userAgent}")

  $view.find(".version_copy").on "click", ->
    app.clipboardWrite($(".version_text").text())
    return

  #忍法帖関連機能
  do ->
    fn = (res, $ul) ->
      if res.length is 0
        $ul.remove()
      else
        frag = document.createDocumentFragment()

        for info in res
          li = document.createElement("li")
          li.setAttribute("data-site_id", info.site.site_id)

          div = document.createElement("div")
          div.textContent = "#{info.site.site_name} : #{info.value}"
          li.appendChild(div)

          button = document.createElement("button")
          button.type = "button"
          button.textContent = "削除"
          button.className = "del_ninja_cookie"
          li.appendChild(button)

          frag.appendChild(li)

        $ul.append(frag)

    app.ninja.get_cookie().done (res) ->
      fn(res, $view.find(".ninja_cookie_info"))

    $view.delegate ".del_ninja_cookie", "click", ->
      $this = $(@)
      $.dialog("confirm",
          message: "本当に削除しますか？",
          label_ok: "はい",
          label_no: "いいえ"
        )
        .done (result) ->
          if result
            $this
              .attr("disabled", true)
              .text("削除中")
            site_id = $this.parent().attr("data-site_id")
            app.ninja.delete_cookie(site_id)
              .done ->
                $this.parent().fadeOut ->
                  $this = $(@)
                  $parent = $this.parent()
                  $this.remove()
                  if $parent.children().length is 0
                    $parent.remove()

  #板覧更新ボタン
  $view.find(".bbsmenu_reload").on "click", ->
    $button = $(@)
    $status = $view.find(".bbsmenu_reload_status")

    $button.attr("disabled", true)
    $status
      .removeClass("done fail")
      .addClass("loading")
      .text("更新中")

    BBSMenu.get((res) ->
      $button.removeAttr("disabled")
      $status.removeClass("loading")
      if res.status is "success"
        $status
          .addClass("done")
          .text("更新完了")

        iframe = parent.document.querySelector("iframe[src^=\"/view/sidemenu.html\"]")
        if iframe
          tmp = JSON.stringify(type: "request_reload")
          iframe.contentWindow.postMessage(tmp, location.origin)

        #TODO [board_title_solver]も更新するよう変更
      else
        $status
          .addClass("fail")
          .text("更新失敗")
      return
    , true)
    return

  #履歴
  do ->
    $clear_button = $view.find(".history_clear")
    $status = $view.find(".history_status")

    #履歴件数表示
    app.History.count().done (count) ->
      $status.text("#{count}件")
      return

    #履歴削除ボタン
    $clear_button.on "click", ->
      $clear_button.remove()
      $status.text("削除中")

      $.when(app.History.clear(), app.read_state.clear())
        .done ->
          $status.text("削除完了")
          parent.$("iframe[src=\"/view/history.html\"]").each ->
            @contentWindow.$(".view").trigger("request_reload")
        .fail ->
          $status.text("削除失敗")
      return

  #キャッシュ削除ボタン
  do ->
    $clear_button = $view.find(".cache_clear")
    $status = $view.find(".cache_status")

    cache = new Cache("*")
    cache.count().done (count) ->
      $status.text("#{count}件")
      return

    $clear_button.on "click", ->
      $clear_button.remove()
      $status.text("削除中")

      cache.delete()
        .done ->
          $status.text("削除完了")
          return
        .fail ->
          $status.text("削除失敗")
          return
      return

  #ブックマークフォルダ変更ボタン
  $view.find(".bookmark_source_change").bind "click", ->
    app.message.send("open", url: "bookmark_source_selector")
    return

  #ブックマークインポートボタン
  $view.find(".import_bookmark").on "click", ->
    rcrx_webstore = "hhjpdicibjffnpggdiecaimdgdghainl"
    rcrx_debug = "bhffdiookpgmjkaeiagoecflopbnphhi"
    req = "export_bookmark"

    $button = $(@)
    $status = $(".import_bookmark_status")

    $button.attr("disabled", true)
    $status.text("インポート中")

    $.Deferred (deferred) ->
      parent.chrome.extension.sendRequest rcrx_webstore, req, (res) ->
        if res
          deferred.resolve(res)
        else
          deferred.reject()
    .pipe null, ->
      $.Deferred (deferred) ->
        parent.chrome.extension.sendRequest rcrx_debug, req, (res) ->
          if res
            deferred.resolve(res)
          else
            deferred.reject()
    .done (res) ->
      for url, bookmark of res.bookmark
        if typeof(url) is typeof(bookmark.title) is "string"
          app.bookmark.add(url, bookmark.title)
      for url, bookmark of res.bookmark_board
        if typeof(url) is typeof(bookmark.title) is "string"
          app.bookmark.add(url, bookmark.title)
      $status.text("インポート完了")
    .fail ->
      $status.text("インポートに失敗しました。read.crx v0.73以降がインストールされている事を確認して下さい。")
    .always ->
      $button.attr("disabled", false)

  #「テーマなし」設定
  if app.config.get("theme_id") is "none"
    $view.find(".theme_none").attr("checked", true)

  app.message.add_listener "config_updated", (message) ->
    if message.key is "theme_id"
      $view.find(".theme_none").attr("checked", message.val is "none")
    return

  $view.find(".theme_none").on "click", ->
    app.config.set("theme_id", if @checked then "none" else "default")
    return

  return
