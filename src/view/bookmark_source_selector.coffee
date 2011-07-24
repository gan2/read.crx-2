app.boot "/view/bookmark_source_selector.html", ->
  $view = $(document.documentElement)

  app.view_module.view($view)

  $view
    .delegate ".node", "click", ->
      $(this)
        .closest(".view_bookmark_source_selector")
          .find(".selected")
            .removeClass("selected")
          .end()
          .find(".submit")
            .removeAttr("disabled")
          .end()
        .end()
        .addClass("selected")
      return

    .find(".submit")
      .bind "click", ->
        bookmark_id = (
          $(this)
            .closest(".view_bookmark_source_selector")
              .find(".node.selected")
                .attr("data-bookmark_id")
        )
        app.bookmark.change_source(bookmark_id)
        parent.postMessage(JSON.stringify(type: "request_killme"), location.origin)
        return

  fn = (array_of_tree, ul) ->
    for tree in array_of_tree
      if tree.children?
        li = document.createElement("li")
        span = document.createElement("span")
        span.className = "node"
        span.textContent = tree.title
        span.setAttribute("data-bookmark_id", tree.id)
        li.appendChild(span)
        ul.appendChild(li)

        cul = document.createElement("ul")
        li.appendChild(cul)

        fn(tree.children, cul)
    null

  chrome.bookmarks.getTree (array_of_tree) ->
    fn(array_of_tree[0].children, $view.find(".node_list > ul")[0])
