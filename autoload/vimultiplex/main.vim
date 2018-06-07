let g:vimultiplex_main = {}

function! vimultiplex#main#new()
    let obj = {}
    let obj.panes = {}
    let obj.current_window = vimultiplex#main#_get_current_window()

    let obj.main_pane_id = vimultiplex#main#active_pane_id()

    " let obj.create_pane = function('vimultiplex#main#create_pane')
    function! obj.create_pane(name)
        let self.panes[a:name] = vimultiplex#pane#new(a:name)
        call self.panes[a:name].initialize_pane()
        let self.panes[a:name].pane_id = vimultiplex#main#newest_pane_id()
    endfunction

    return obj
endfunction

function! vimultiplex#main#_get_current_window()
    return substitute(system("tmux display-message -p '#{window_id}'"),'\n\+$','','')
endfunction

function! vimultiplex#main#start()
    let g:vimultiplex_main = vimultiplex#main#new()
endfunction

function! vimultiplex#main#get_pane_data()
    let pane_data = split(system("tmux list-panes"), "\n")
    let parsed_pane_data = []
    for i in pane_data
        let current_pane_data = matchlist(i, '\v^(\d+): \[(\d+x\d+)\] \[[^\]]+\] (\%\d+) ?\(?(active)?\)?')
        call add(parsed_pane_data, { 'pane_listing': current_pane_data[1], 'pane_id': current_pane_data[3], 'active': current_pane_data[4]} )
    endfor
    return parsed_pane_data
endfunction

function! vimultiplex#main#active_pane_id()
    let pane_data = vimultiplex#main#get_pane_data()
    let pane_id = ''

    for i in pane_data
        if i.active ==# 'active'
            let pane_id = i.pane_id
        endif
    endfor

    return pane_id
endfunction

function! vimultiplex#main#newest_pane_id()
    let pane_data = vimultiplex#main#get_pane_data()

    let found_pane = {}
    let max_found_id = ''

    for i in pane_data
        let short_pane_id = i.pane_id
        let short_pane_id = substitute(short_pane_id, '%', '', '')
        if max_found_id ==# '' || short_pane_id >=# max_found_id
            let found_pane = i
            let max_found_id = short_pane_id
        endif
    endfor

    return found_pane.pane_id
endfunction

