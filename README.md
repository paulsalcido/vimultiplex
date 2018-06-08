# Vimultiplex

The goal of this project was to be able to create named panes in tmux that will
allow me to control various things at the same time in panes in one window.
While trying to do that, I discovered some very ugly truths about the way that
tmux works, and simultaneously learned some of the ugly truths about coding in
vimscript.  That's a different issue, but here I am, with a somewhat working
plugin.

## Installation

While there are a number of ways to install vim plugins, I currently use
pathogen.  Checkout a copy of this respository, and once you have done so,
link it in your ~/.vim/bundle/ directory.

## Controlling Panes

When writing vimultiplex, I wanted to be able to send keys to a named pane.  Of
course, tmux does not have an equivalent.  Thus, I decided to do most of the
work in vimscript.

First, we need to initialize this utility:

```
:call vimultiplex#main#start()
```

This will set up the global object that is used by vimultiplex to know about the
panes that it creates.

```
:call g:vimultiplex_main:create_pane('test', { 'percentage': 20 })
```

Creates a 20% tall pane in the current window, splitting the vim pane
vertically.

```
:call g:vimultiplex_main:create_pane('test2', { 'target': 'test', 'horizontal': 1, }
```

This will split the current pane horizontally into two equally sized panes.

```
:call g:vimultiplex_main:send_keys('test2', @@)
```

Will send the contents of the main paste buffer to the second pane you created.

```
:call g:vimultiplex_main:destroy_pane('test')
```

Gets rid of your first pane.

```
call g:vimultiplex_main:delete_destroyed_panes()
```

If any of the panes created by vimultiplex are destroyed outside of vim (by
navigating to the pane and exiting, for instance, or by a command finishing)
then this will clean up.

Not really a lot more to it just yet.

## Author

Paul David Salcido paulsalcido.79 <at> gmail <dot> com
