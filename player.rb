require 'date'
require 'time'

class Player
  attr_reader :username
  attr_reader :date
  attr_reader :name
  attr_reader :reservations

  @@players = Array.new
  def Player.initialize(configurations, log)
    configurations.each do |configuration|
      @@players << Player.new(configuration, log)
    end
  end

  def Player.players
    @@players
  end

  def Player.have_players?
    not @@players.empty?
  end

  def Player.admin
    @@players[0]
  end

  def Player.get_existing_reservations
    courts_as_string = []
    @@players.each do |player|
      player.reservations.each do |reservation|
        courts_as_string << reservation.to_s
        break
      end
    end
    courts_as_string.join(". ")
  end

  def Player.logout
    @@players.each do |player|
      player.logout
    end
  end

  def Player.find_available_player(start_time)
    @@players.each do |player|
      if player.can_make_reservation?(start_time)
        return player
      end
    end
  end

  def initialize(attributes, log)
    @username = attributes[:username]
    @password = attributes[:password]
    @date = Date::today + 3
    @reservations = Array.new
    @days = Set.new
    for day in attributes[:days_available]
      @days.add Date.parse(day).wday
    end
    @log = log

    # login
    login
    # find existing reservations
    get_existing_reservations
  end

  def reserve(reservation)
    begin
      # pick court and time
      court, court_name = pick_court(reservation)

      if court.nil?
        @log.warn "Court " + court_name + " is not available @ " + reservation.start_time
      else
        @log.debug "About to schedule " + court_name + " @ " + reservation.start_time + " on " + dateStr + " for " + name
        court.click
        f = @b.frame(:name => "mainFrame")
        players = f.text_fields(:name => "txtPname")
        players[1].set 'Will Fill'
        players[2].click

        @b.alert.ok
        f.img(:name => 'schedule').click
        cancel = @b.frame(:name => "mainFrame").img(:name => "cancel")
        if cancel.exists?
          error = @b.frame(:name => "mainFrame").font(:color => "blue")
          if error.exists?
            @log.warn "Unable to schedule court for reason: " + error.text
          else
            @log.warn "Unable to schedule court for unknown reason"
          end
          cancel.click
          if @b.alert.exists?
            @b.alert.ok
          end
        end
        reservation.make_reservation
        log.info "Reserved " + court.to_s + " on " + player.dateStr + " for " + player.name
      end
    rescue Exception => exception
      @log.warning exception.message
      @log.warning exception.backtrace.inspect
      logout
      login
      retry
    end
  end

  def pick_court(reservation)
    f = @b.frame(:name => "mainFrame").frame(:name => "bottom")
    tbody = f.table.tbody

    reservation.court_preference.delete_if do |preferred_court|
      unless court.exists?
        if preferred_court == "Center"
          court_name = "Center Court"
        else
          court_name= "Court %d" % preferred_court
        end
        court = tbody.img(:title => /#{court_name} is Available for Block Schedule from #{reservation.start_time} to .*/)
        unless court.exists?
          court = tbody.img(:title => /#{court_name} is Available at #{reservation.start_time}/)
        end
        return court, court_name
      end
    end
  end

  def logout
    @b.close
  end

  def can_make_reservation?(start_time)
    if not @days.include?(@date.wday)
      @log.warn @name + " does not schedule on " + @date.strftime('%A') + "s"
      return false
    end
    if @reservations.size >= 6
      @log.warn @name + " already has 2 court reservations, which is the max per day"
      return false
    end
    @reservations.each do |existing_reservation|
      if existing_reservation.overlaps?(start_time)
        @log.warn(@name + " already has a court reservation that overlaps with " +
                      start_time.strftime('%I:%M%p'))
        return false
      end
    end
    true
  end

  def get_existing_reservations
    begin
      @b.frame(:name => "mainFrame").wait_until_present
      f = @b.frame(:name => "mainFrame").frame(:name => "bottom")
      tbody = f.table.tbody
      num_previous_reservations = @reservations.size
      for image in tbody.imgs(:title => /Open Play .* for #{@name}/)
        m = /Open Play on CT(.*), for #{@name}, .* scheduled at (.*)/.match(image.title)
        if m and m.captures.size == 2
          court = m.captures[0]
          time = m.captures[1]
          if court == "CC"
            court = "Center"
          end
          start_time = Time.parse(time)

          if not reservation_exists?(court, start_time)
            @log.info @name + " has Court " + court + " @ " + time + " on " + dateStr
            @reservations << CourtReservation.new(court, start_time)
          end
        end
      end
      @reservations.size > num_previous_reservations
    rescue Exception => exception
      @log.warning exception.message
      @log.warning exception.backtrace.inspect
      logout
      login
      retry
    end
  end

  def reservation_exists?(court, time)
    for existingReservation in @reservations
      if existingReservation.court == court and existingReservation.start_time == time
        return true
      end
    end
    false
  end

  def dateStr
    @date.strftime('%m/%d/%Y')
  end

  private
  def login
    begin
      # @b = Watir::Browser.new :phantomjs
      # @b = Watir::Browser.new :firefox
      @b = Watir::Browser.new :chrome
      @b.goto "http://eclubconnect.com/rci"
      @b.goto "http://eclubconnect.com/rci/default1.asp?clr=ss&h2=h2&idi=133"
      @b.frame(:name => "CenterFrame").wait_until_present
      f = @b.frame(:name => "CenterFrame")
      f.text_field(:name => 'Mtxtlogin').when_present.set @username
      f.text_field(:name => 'Mtxtpwd').when_present.set @password
      f.button(:name => 'cmdSubmit').click

      # Extract name
      @name = @b.frame(:name => "header").table().table.font(:color => "white").text

      # pick date
      date_str = "%d/%d/%d" % [@date.month, @date.day, @date.year]
      f = @b.frame(:name => "mainFrame").frame(:name => "middle")
      form = f.form(:id => "frmSch")
      if @date.month > Date.today.month
        next_month_link = "/application/esch_ematch/testcal.asp?month=%d&year=%d" % [@date.month, @date.year]
        form.a(:href => next_month_link).click
      end
      f = @b.frame(:name => "mainFrame").frame(:name => "middle")
      form = f.form(:id => "frmSch")
      form.a(:href => "javascript:setDate('" + date_str + "')").click
    rescue
      retry
    end
  end
end
