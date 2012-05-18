#"thread" is required for the mutexes
require "thread"
class ChatServer
  def initialize

    #we will keep track of the names
    #and sessions in arrays, and protect
    #them from parallel updates with mutexes
    @names = []
    @sessions = []
    @sessionmutex = Mutex.new
    @namemutex = Mutex.new
  end

  #the chat application will use this function
  #to determine which sessions to broadcast to
  def sessionsbutthis(ses)
    @sessionmutex.synchronize{
      copy = Array.new @sessions
      copy.delete ses
      copy
    }
  end

  #functions to register and remove sessions
  def releasesession(ses)
    @sessionmutex.synchronize{
      @sessions.delete ses
    }
  end
  def addsession(ses)
    @sessionmutex.synchronize{
      @sessions << ses
    }
  end

  #function to reserve a name, returns the
  #modified name it could reserve
  def reservename(name)
    @namemutex.synchronize{
      if @names.include? name
        i = 1
        while @names.include?(name + i.to_s)
          i += 1
        end
        name = (name + i.to_s)
      end
      @names << name
      name
    }
  end

  #unregister the name
  def releasename(name)
    @namemutex.synchronize{
      @names.delete name
    }
  end
end

#global chatserver object, to keep track of the things
$chatserver = ChatServer.new
