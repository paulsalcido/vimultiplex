let g:vimultiplex_main = {}

" vimultiplex#main#new
"
" Creates a new vimultiplex window controller.
"
" A window controller contains the following member data:
"   * panes: A dictionary containing the panes created by vimultiplex
"     * For more details, see vimultiplex#pane
"   * current_window: The current window id
"   * main_pane_id: The pane id for the pane that vim is running in.
"
" A window controller contains the following methods:
"   * create_pane(name, options):
"     Creates a pane for the current (main) window.
"   * send_keys(name, text): Sends 'text' to the pane with the name
"     'name'.  The name is resolved to the pane index value based on the
"     id stored in the pane object.
"   * destroy_pane(name)
"     Kill a pane and remove it from the window list.
"   * delete_destroyed_panes
"     Get rid of internally stored pane data where the pane has been removed
"     elsewhere.  An unfortunate reality of tmux.

function! vimultiplex#main#new()
    let obj = {}
    let obj.panes = {}
    let obj.current_window = vimultiplex#window#new('main', {'preinitialized': 1, })
    let obj.windows = {'main': obj.current_window, }
    call obj.current_window.set_id(vimultiplex#main#get_current_window())
    let obj.main_pane_id = vimultiplex#main#active_pane_id(vimultiplex#main#get_current_window())

    function! obj.create_pane(name, options)
        let window_to_use = self.current_window
        if exists("a:options['window']")
            let window_name = remove(a:options, 'window')
            if ! self.has_window(window_name)
                echoerr "vimultiplex: No window named " . window_name
                return
            endif
            let window_to_use = self.windows[window_name]
        endif
        call window_to_use.create_pane(a:name, a:options)
    endfunction

    function! obj.create_window(name, settings)
        let self.windows[a:name] = vimultiplex#window#new(a:name, a:settings)
        call self.windows[a:name].initialize()
        call self.windows[a:name].set_id(vimultiplex#window#newest_window_id())
        " TODO: Get the new pane created and give it a name, have
        " default_pane_name be an option that can be set, or else it gets the
        " name of the new window.
        let new_pane_name = a:name
        if exists("a:settings['default_pane_name']")
            let new_pane_name = a:settings['default_pane_name']
        endif
        call self.windows[a:name].setup_default_pane(new_pane_name)
    endfunction

    function! obj.send_keys(name, text)
        call self.window_with_named_pane(a:name).send_keys(a:name, a:text)
    endfunction

    function! obj.get_pane_by_name(name)
        return self.window_with_named_pane(a:name).get_pane_by_name(a:name)
    endfunction

    function! obj.destroy_pane(name)
        call self.window_with_named_pane(a:name).destroy_pane(a:name)
    endfunction

    function! obj.delete_destroyed_panes()
        for i in keys(self.windows)
            call self.windows[i].delete_destroyed_panes()
            if i !=# 'main'
                call remove(self.windows, i)
            endif
        endfor
    endfunction

    function! obj.window_with_named_pane(name)
        call self.fill_windows()

        for i in keys(self.windows)
            if self.windows[i].has_named_pane(a:name)
                " I don't like this, but there isn't a for stop (last in perl)
                " that I know of.
                return self.windows[i]
            endif
        endfor

        return ''
    endfunction

    function! obj.fill_windows()
        echom "Filling known windows"
        let known_windows = vimultiplex#window#get_window_data()

        for i in known_windows
            echom "known: " . i.window_id
            let current_name = self.get_window_name(i.window_id)
            echom "current_name: " . current_name
            if current_name ==# ''
                " Add the window here.
                let self.windows[i.window_id] = vimultiplex#window#new(i.window_id, {'preinitialized': 1, })
                call self.windows[i.window_id].set_id(i.window_id)
                call self.windows[i.window_id].update_pane_listing()
            endif
        endfor
    endfunction

    function! obj.get_window_name(id)
        for i in keys(self.windows)
            if self.windows[i].window_id ==# a:id
                return i
            endif
        endfor
        return ''
    endfunction

    function! obj.destroy_all()
        for i in keys(self.windows)
            call self.windows[i].destroy_all()
            call remove(self.windows, i)
        endfor
    endfunction

    function! obj.has_window(name)
        return exists('self.windows[a:name]')
    endfunction

    return obj
endfunction

" Static methods of this vimultiplex.

" vimultiplex#main#get_current_window()
"
" Get the current window id.

function! vimultiplex#main#get_current_window()
    return substitute(system("tmux display-message -p '#{window_id}'"),'\n\+$','','')
endfunction

" vimultiplex#main#start()
"
" Initializes the global object g:vimultiplex_main as a new vimultiplex window
" controller.

function! vimultiplex#main#start()
    let g:vimultiplex_main = vimultiplex#main#new()
endfunction

" vimultiplex#main#active_pane_id()
"
" The current active pane id.  See window#get_pane_data()

function! vimultiplex#main#active_pane_id(window_id)
    let pane_data = vimultiplex#window#get_pane_data()
    let pane_id = ''

    for i in pane_data
        if i.active ==# '1' && i.window_id ==# a:window_id
            let pane_id = i.pane_id
        endif
    endfor

    return pane_id
endfunction

" vimultiplex#main#get_pane_index_by_id(pane_id)
"
" Get the pane index (the first number listed in tmux list-panes) based on the
" pane id (the last number listed in tmux list-panes).

function! vimultiplex#main#get_pane_index_by_id(pane_id)
    let pane_data = vimultiplex#window#get_pane_data()
    let pane_index = -1

    for i in pane_data
        if i.pane_id ==# a:pane_id
            let pane_index = i.pane_index
        endif
    endfor

    return pane_index
endfunction
