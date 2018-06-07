function! vimultiplex#pane#new(name)
    let obj = {}
    let obj['name'] = a:name

    function! obj.initialize_pane()
        call system("tmux split-window -d")
    endfunction

    return obj
endf
