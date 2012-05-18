#default boilerplate for JWt
require 'java'

import "eu.webtoolkit.jwt.WContainerWidget"
import "eu.webtoolkit.jwt.WBreak"
import "eu.webtoolkit.jwt.WApplication"
import "eu.webtoolkit.jwt.WLineEdit"
import "eu.webtoolkit.jwt.WText"
import "eu.webtoolkit.jwt.WLength"
import "eu.webtoolkit.jwt.Side"
import "eu.webtoolkit.jwt.WInPlaceEdit"
import "eu.webtoolkit.jwt.Cursor"
import "eu.webtoolkit.jwt.WColor"
import "eu.webtoolkit.jwt.WBorder"

#use the parts shown previously
require "ChatServer"

#subclass the WApplication class
class ChatApp < WApplication
  def initialize(env)
    super

    #just login with the name "guest" for now
    @name = $chatserver.reservename "guest"

    #let's get the id of the div to connect to
    #from the div query parameter
    @div = env.getParameter("div");
    @top = WContainerWidget.new
    if ! @div.nil?
      setJavaScriptClass @div;
      bindWidget @top, @div
    else
      quit
      return
    end

    #enable push updates
    enableUpdates

    #resize the top level container to some sane width
    @top.resize WLength.new("60mm"), WLength.Auto

    #set a really nice(TM) background color
    @top.getDecorationStyle.setBackgroundColor WColor.new("lightblue")


    #set up the widgets: a container widget to hold
    #the chat lines, with a height of 480 pixels,
    #and scroll bar displayed only if the text overflows

    #the title container holds the user name, the close button
    #and opens the chat window when clicked on
    @titlecontainer = WContainerWidget.new @top
    @titlecontainer.resize WLength.new("100%"), WLength.Auto
    @titlecontainer.getDecorationStyle.setBackgroundColor(WColor.new "blue")
    @titlecontainer.getDecorationStyle.setCursor Cursor::PointingHandCursor

    #this container is necessary, to stop mouse clicks from
    #propagating from the nameeditor
    subcontainer = WContainerWidget.new @titlecontainer
    subcontainer.setInline true
    subcontainer.clicked.preventPropagation

    #the name editor - this displays and sets the user name
    @nameeditor = WInPlaceEdit.new @name, subcontainer
    @nameeditor.setButtonsEnabled false
    @nameeditor.getTextWidget.getDecorationStyle.setCursor Cursor::PointingHandCursor
    @nameeditor.getDecorationStyle.setForegroundColor(WColor.new "white")

    #if the user name changes, release the old name,
    #reserve the new one, and update the display again
    @nameeditor.valueChanged.add_listener(self){|newvalue|
      $chatserver.releasename @name
      @name = $chatserver.reservename newvalue.getValue
      @nameeditor.setText @name
    }

    #window closer, on the right side of the title
    #again, notice the preventPropagation call
    @windowcloser = WText.new 'X', @titlecontainer
    @windowcloser.setFloatSide Side::Right
    closesignal = @windowcloser.clicked
    closesignal.add_listener(self) do
      if ! @rest.nil?
        @rest.hide
      end
    end
    closesignal.preventPropagation

    #set up the chat container when clicking on the
    #title, or simply show it if it's already set up
    @titlecontainer.clicked.add_listener(self) do
      if @rest.nil?
        setuprest
        return
      end
      @rest.show
      @chatinput.setFocus
    end

    #register this session with the chat server
    $chatserver.addsession self
  end

  #let's set up the missing widgets
  def setuprest

    #add the container which holds the
    #chat-line container, and the input box
    @rest = WContainerWidget.new @top

    @chatcontainer = WContainerWidget.new @rest
    @chatcontainer.resize WLength.new("99%"), WLength.Auto
    @chatcontainer.setOverflow(WContainerWidget::Overflow::OverflowAuto)

    #chat input line, set to fit the width of the chat box
    @chatinput = WLineEdit.new @rest
    @chatinput.resize WLength.new("99%"), WLength.Auto


    #on enter press, display the text in the user's own session
    #with addstring, and push the text out to every other session
    #with pushstring
    @chatinput.enterPressed.add_listener(self) do
      #puts "INPUT: "+@chatinput.getText
      addstring("me: " + @chatinput.getText)
      $chatserver.sessionsbutthis(self).each{|i|
        i.pushstring @name + ": " + @chatinput.getText
      }
      @chatinput.setText ""

    end

    #let's focus :)
    @chatinput.setFocus
  end

  #JWt calls the destroy function when the window for this session is
  #closed. So notify the other users, and unregister the name and the session.
  def destroy
    $chatserver.sessionsbutthis(self).each{|i|
      i.pushstring "Logged out:" + @name
    }
    $chatserver.releasesession self
    $chatserver.releasename @name
  end


  #This function is called from other sessions to push a line to this
  #chat window
  #This is where the "server push" happens.
  def pushstring(s)

    #take the update lock to serialize the requests
    lock = getUpdateLock
    begin

      #simply call addstring to actually display the text
      addstring(s)

      #call triggerUpdate to push the changes to the browser
      triggerUpdate
    rescue
    end

    #do not forget to release the lock!
    lock.release
  end

  private

  #adds a string to the chat container
  def addstring(s)

    #let's just skip it if the chat container is not yet initalised
    if @rest.nil?
      return
    end

    #adds a string to the chat container
    w = WText.new s, @chatcontainer

    #set inline to false, so every string appears
    #on a new line
    w.setInline false

    #remove a line if already more than 5 are displayed
    if @chatcontainer.getCount > 5
      @chatcontainer.removeWidget @chatcontainer.getWidget 0
    end

    #push some JavaScript to the client side, to make the
    # chat container scroll to the bottom
    #originally from the JWt SimpleChat example
    doJavaScript(@chatcontainer.getJsRef + ".scrollTop += "+@chatcontainer.getJsRef() + ".scrollHeight;")
  end
end


