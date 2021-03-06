# TODO: add timestamps each time the status_message is changed
# TODO: add some tabbing to status output for better readability

require File.join(File.dirname(__FILE__), 'init' )

campfire = Tinder::Campfire.new ACCOUNT
campfire.login LOGIN, PASSWORD
room = campfire.find_room_by_name ROOM

# Ouch.  Use built-in AR methods...
def fetch_or_create_user(name)
  if User.exists?(:name => name)
    user = User.find_by_name(name)
  else
    user = User.new(:name => name, :status => "active")
  end
  user
end



room.listen do |message|
  user = fetch_or_create_user(message[:person])
  
  # ======================
  # = Message operations =
  # ======================
  
  # Archive messages
  unless MESSAGE_EXCEPTIONS.include?(message[:person])
    unless message[:message] == ""
      user.messages << Message.new( :message => message[:message], :message_id => message[:id] )
      user.save
    end
  end


  # Auto-back feature
  if user.status == "away" and message[:message] !~ /^\/away(\s(.+))?/ and message[:message] !~ /has left the room/
    user.update_attributes( :status => "active" )
  end
  
  
  # auto-away status
  if message[:message] =~ /has left the room/
    user.update_attributes( :status => "away", :status_message => "" )
  end
  
  
  # Auto-active status
  if message[:message] =~ /has entered the room/
    user.update_attributes( :status => "active" )
  end
  
  
  # =========
  # = /sing =
  # =========
  if message[:message] == "/sing"
    room.speak "Binary Solo! 0000001 00000011 000000111 000001111 http://www.youtube.com/watch?v=B1BdQcJ2ZYY"
  end
  
  
  # =========================
  # = /search search string =
  # =========================
  if message[:message] =~ /^\/search\s(.+)/
    query = $1.gsub(/\s/, "+")
    google_data = Scrubyt::Extractor.define do
      fetch "http://www.google.com/search?hl=en&q=#{query}"
      link_title "//a[@class='l']", :write_text => true do
        link_url
      end
    end
    results = google_data.to_hash
    for i in 0..4
      room.speak "#{i+1}. #{results[i][:link_title]} -> #{results[i][:link_url]}"
    end
  end
  
  
  # =====================
  # = /topic room topic =
  # =====================
  if message[:message] =~ /^\/topic\s(.+)/
    room.topic = $1
  end


  # ========================
  # = /toggle guest access =
  # ========================
  if message[:message] == "/toggle guest access"
    room.toggle_guest_access
  end
  
  
  # =================
  # = /away message =
  # =================
  if message[:message] =~ /^\/away(\s(.+))?/
    user.status = "away"
    user.status_message = $2 if $2
    if user.save
      if $2
        room.speak message[:person] + " is now away: #{$2}"
      else
        room.speak message[:person] + " is now away"
      end
    else
      room.speak "Oops, problem."
    end  
  end
  
  
  # ===================
  # = /status message =
  # ===================
  if message[:message] =~ /^\/status\s(.+)?/
    user.status_message = $1
    if user.save
      room.speak "#{message[:person]} is currently #{user.status}: #{user.status_message}"
    else
      room.speak "Oops, problem."
    end  
  end
  
  
  # ===========
  # = /status =
  # ===========
  if message[:message] == "/status"
    users = User.all
    ret = "This is what I know:\r\n"
    users.each do |user|
      ret << "#{user.name} is currently #{user.status}"
      ret << ": #{user.status_message}" unless user.status_message.blank?
      ret << "\r\n"
    end
    room.paste ret
  end


  # =================
  # = /back message =
  # =================
  if message[:message] =~ /^\/back(\s(.+))?/
    room.speak "This command has been deprecated in favor of automatic status updating.  To set your active status, use /status instead."
  end
  
  
  # ====================
  # = /earmuffs on|off =
  # ====================
  if message[:message] =~ /^\/earmuffs\s(o(n|ff))$/
    Admin.listeners_active = $1 == "off"
    room.speak "Earmuffs are now #{$1}"
  end
  
  
  # =============
  # = /earmuffs =
  # =============
  if message[:message] =~ /^\/earmuffs$/
    room.speak "Earmuffs are currently #{Admin.listeners_active ? "off" : "on"}"
  end
  
  
  # =========
  # = /joke =
  # =========
  if message[:message] == "/joke"    
    joke = Scrubyt::Extractor.define do
      fetch "http://www.ajokeaday.com/ChisteAlAzar.asp"
      joke_text "//div[@class='chiste']"
    end
    results = joke.to_hash
    room.speak results[0][:joke_text]
  end
  
  
  # ==========
  # = /chuck =
  # ==========
  if message[:message] == "/chuck"    
    joke = Scrubyt::Extractor.define do
      fetch "http://4q.cc/index.php?pid=fact&person=chuck"
      joke_text "//div[@id='factbox']"
    end
    results = joke.to_hash
    room.speak results[0][:joke_text]
  end
  
  
  # ==========
  # = /mrt =
  # ==========
  if message[:message] == "/mrt"    
    joke = Scrubyt::Extractor.define do
      fetch "http://4q.cc/index.php?pid=fact&person=mrt"
      joke_text "//div[@id='factbox']"
    end
    results = joke.to_hash
    room.speak results[0][:joke_text]
  end


  # =================
  # = /slap Nate T. =
  # =================
  if message[:message] =~ /^\/slap(\s(.+))?/
    name = $1.strip
    names = []
    room.users.each { |u| names.push(u.to_s.gsub!("<span class=\"name\">", "").gsub!("</span>", "").strip)}
    if names.include? name
      room.speak "#{message[:person]} slaps #{name} around with a large trout."
    else
      room.speak "Pssshh! Hey buddy...just a hint, but #{name} isn't here right now."
    end
  end

  # ===============
  # = /shutup foo =
  # ===============
  if message[:message] =~ /^\/shutup\s(.+)?/
    room.speak "OH SNAP #{$1}! You just got BOOM ROASTED."
  end
  
  
  # ====================
  # = /finger Nate T. =
  # ====================
  if message[:message] =~ /^\/finger\s(.+)?/
    if User.exists?(:name => $1)
      user = User.find_by_name($1)
      ret = "User: #{user.name}\r\n"
      ret << "Status: #{user.status}\r\n"
      ret << "Status Message: #{user.status_message}\r\n" unless user.status_message.blank?
      ret << "Message Count: #{user.messages.count}\r\n"
      ret << "Last Message: #{user.messages.last.message}\r\n"
      ret << "Last Active: #{to_pretty(user.updated_at)}\r\n"
      room.paste ret
    else
      room.speak "Sorry, I don't know about #{$1}"
    end
  end
  
  
  # ==================
  # = /weather 46845 =
  # ==================
  if message[:message] =~ /^\/weather\s(.+)?/
    zip = $1
    if (zip =~ /^\d{5}([\-]\d{4})?$/)
      client = YahooWeather::Client.new
      begin
        response = client.lookup_location(zip)
        room.speak "#{response.title} #{response.condition.temp} degrees #{response.condition.text}"  
      rescue
        room.speak "Yahoo doesn't think this a valid zip"
      end
    else
      room.speak "Sorry, I only know 5 digit zip codes at this point"
    end
  end
  
  
  # =============
  # = /random 8 =
  # =============
  if message[:message] =~ /^\/random\s(.+)?/
    chars = $1
    if (chars =~ /\d/)
      srand
      seed = "--#{rand(10000)}--#{Time.now}--"
      room.speak Digest::SHA1.hexdigest(seed)[0,chars.to_i]
    else
      room.speak "Sorry, I can only generate a kick-ass random string if you pass me a valid length"
    end
  end
  
  
  # =============
  # = /pomodoro =
  # =============
  if message[:message] =~ /^\/pomodoro\s(.+)?/
    t = Time.now 
    f = t + (25 * 60)
    tstamp = t.strftime("%I:%M%p")
    fstamp = f.strftime("%I:%M%p")
    room.speak "#{user.name} will be away for 25 minutes"
    user.update_attributes( :status_message => "started a pomodoro at #{tstamp.to_s} and will be inactive until at least #{fstamp.to_s}")
  end
  
  # ===============
  # = /shutup foo =
  # ===============
  if message[:message] =~ /^\/shutup\s(.+)?/
    room.speak "OH SNAP #{$1}! You just got BOOM ROASTED."
  end
  
  # ==============
  # = /katz
  # ==============
  if message[:message] == "/katz"
    room.upload File.join(File.dirname(__FILE__), 'files', 'yehuda-katz.jpg' )
  end
  
  # ==============
  # = /debug
  # ==============
  if message[:message] == "/debug"
    room.speak "current Dir: #{Dir.pwd.to_s}"
    room.speak "current users: "
    room.users.each do |user|
      room.speak "- #{user.to_s.gsub!("<span class=\"name\">", "").gsub!("</span>", "")}"
    end
  end
  
  # =====================
  # = General Listeners =
  # =====================
  if Admin.listeners_active 		    	  # Controlled with /earmuffs command
	  
	  if message[:person] != "GitHub"		  # Disallow GitHub bot interference when people commit
  	  Listener.all.each do |handler|
  	    if message[:message] =~ Regexp.new(handler[0])
  	      room.speak handler[1]
  	    end
  	  end
  	end
  	
  end
  
end