let g:vimultiplex_main = {}

" vimultiplex#main#new
"
" Creates a new vimultiplex window controller.

function! vimultiplex#main#new()
    let obj = {'initialized': 1}

    " current_window is the window that vimultiplex was started in.
    let obj.current_window = vimultiplex#window#new('main', {'preinitialized': 1, })

    " windows: The list of windows that is known by vimultiplex, in a
    " dictionary organized by name.  'main' will be the same as current_window
    let obj.windows = {'main': obj.current_window, }

    call obj.current_window.set_id(vimultiplex#main#get_current_window())

    " Setup the initial pane to have name of 'main'
    call obj.current_window.setup_default_pane('main', {'preinitialized': 1, })

    " main_pane_id: the pane id for the pane that vimultiplex is running in.
    let obj.main_pane_id = vimultiplex#main#active_pane_id(vimultiplex#main#get_current_window())

    " function create_pane(name, options)
    "
    " name is a string and will be used to store the new pane object in the
    " dictionary 'panes' in whatever window this pane will be created.
    "
    " Options is a dictionary and might contain the following keys:
    "   * window: the name of the window that you want to start the new pane
    "   in, if not the current window.  See the method 'fill_window' for more
    "   information about how panes are stored, if not created by vimultiplex.
    "   * target: the pane that will be split by vimultiplex.  If you call
    "   create pane here, you will also need to pass 'window' to the name of
    "   the window with the target pane.  Otherwise, use
    "   self.windows[name].create_pane to create the pane.
    "
    " See vimultplex#window#create_pane for more options.
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

    " function create_window(name, options)
    "
    " Creates a new window to work with.  Panes are sections in a window in
    " tmux, so a new window creation will just add a new tab to tmux. 
    "
    " Options handled:
    "   * default_pane_name: The name of the initial pane created to be
    "   storeed in vimultiplex.  All windows have at least a single pane
    "   running.
    "
    " See vimultiplex#window#new for more options.
    function! obj.create_window(name, options)
        let self.windows[a:name] = vimultiplex#window#new(a:name, a:options)
        call self.windows[a:name].initialize()
        call self.windows[a:name].set_id(vimultiplex#window#newest_window_id())
        " TODO: Get the new pane created and give it a name, have
        " default_pane_name be an option that can be set, or else it gets the
        " name of the new window.
        let new_pane_name = a:name
        if exists("a:options['default_pane_name']")
            let new_pane_name = a:options['default_pane_name']
        endif
        call self.windows[a:name].setup_default_pane(new_pane_name, {})
    endfunction

    " function send_keys(name, text)
    "
    " This sends keys to a named pane.
    function! obj.send_keys(name, text)
        call self.window_with_named_pane(a:name).send_keys(a:name, a:text)
    endfunction

    " function get_pane_by_name(name)
    "
    " Returns a pane object by name.  Searches all windows for that pane.
    function! obj.get_pane_by_name(name)
        return self.window_with_named_pane(a:name).get_pane_by_name(a:name)
    endfunction

    " function set_pane_style(name, style)
    function! obj.set_pane_style(name, style)
        if self.has_named_pane(a:name)
            call self.get_pane_by_name(a:name).update_style(a:style)
        else
            echoerr "Cannot set style for nonexistent pane " . a:name
        endif
    endfunction

    " function has_named_pane(name)
    function! obj.has_named_pane(name)
        let check = type(self.window_with_named_pane(a:name))
        if check ==# 1
            return 0
        elseif check ==# 4
            return 1
        endif
        return 0
    endfunction

    " function destroy_pane(name)
    "
    " Destroys a pane based on a passed name.
    function! obj.destroy_pane(name)
        call self.window_with_named_pane(a:name).destroy_pane(a:name)
    endfunction

    " function delete_destroyed_panes()
    "
    " Sometimes panes are destroyed outside of vimultiplex.  This method finds
    " panes that match that condition and deletes them from the system.
    function! obj.delete_destroyed_panes()
        for i in keys(self.windows)
            call self.windows[i].delete_destroyed_panes()
            if i !=# 'main'
                call remove(self.windows, i)
            endif
        endfor
    endfunction

    " function window_with_named_pane(name)
    "
    " Returns the window object that has a pane by the name 'name'.  It might
    " be wise to guarantee uniqueness somehow (TODO)
    function! obj.window_with_named_pane(name)
        call self.fill_windows()

        for i in keys(self.windows)
            if self.windows[i].has_named_pane(a:name)
                return self.windows[i]
            endif
        endfor

        return ''
    endfunction

    " function fill_windows()
    "
    " Get all windows not managed by vimultiplex and add them to the windows
    " dictionary for this object.
    "
    " Each window has a name like '@\d+', so '@4' or '@125'.  The name that
    " they will have in the dictionary will match this if they are not
    " initially named, and the new objects will be created with the window
    " setting 'preinitialized', which will prevent the 'initialize' call from
    " ever working.
    "
    " You can then create new panes in these windows if you desire, I guess.
    "
    " Also, see the window method 'update_pane_listing' for more information
    " about pane namings.
    function! obj.fill_windows()
        let known_windows = vimultiplex#window#get_window_data()

        for i in known_windows
            let current_name = self.get_window_name(i.window_id)
            if current_name ==# ''
                " Add the window here.
                let self.windows[i.window_id] = vimultiplex#window#new(i.window_id, {'preinitialized': 1, })
                call self.windows[i.window_id].set_id(i.window_id)
                call self.windows[i.window_id].update_pane_listing()
            endif
        endfor
    endfunction

    " function get_window_name
    "
    " Pass in a window name and get the id.  Returns a zero length string if
    " not found.  Returns the key from the window dictionary otherwise.
    "
    " See fill_windows() for more information about window naming.
    function! obj.get_window_name(id)
        for i in keys(self.windows)
            if self.windows[i].window_id ==# a:id
                return i
            endif
        endfor
        return ''
    endfunction

    " function destroy_all
    "
    " Gets rid of all panes and windows known by vimultiplex.  This does so by
    " going through all windows and calling destroy_all on them.  See
    " destroy_all in the windows class for more information about how this
    " avoids closing windows that weren't created by vimultiplex.
    function! obj.destroy_all()
        for i in keys(self.windows)
            call self.windows[i].destroy_all()
            if i !=# 'main'
                call remove(self.windows, i)
            endif
        endfor
    endfunction

    " function has_window(name)
    "
    " Returns true if vimultiplex has a window with a given name.
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
    if ! exists("g:vimultiplex_main['initialized']")
        let g:vimultiplex_main = vimultiplex#main#new()
    endif
endfunction

" vimultiplex#main#active_pane_id()
"
" The current active pane id.  See window#get_pane_data()

function! vimultiplex#main#active_pane_id(window_id)
    let pane_data = vimultiplex#window#get_pane_data()
    let pane_id = ''

    let window_index = vimultiplex#window#get_window_index_by_id(a:window_id)

    for i in pane_data
        if i.active ==# '1' && i.window_id ==# window_index
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
