require 'date'

class Player
  attr_reader :username
  attr_reader :date
  attr_reader :name

  def initialize(attributes, log)
    @username = attributes["username"]
    @password = attributes["password"]
    @date = Date::today + 3
    @reservations = Array.new
    @days = Set.new
    for day in attributes["days_available"]
      @days.add Date.parse(day).wday
    end
    @log = log
  end

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

      # find existing reservations
      get_existing_reservations
    rescue
      retry
    end
  end

  def pick_court_and_time(reservation)
    begin
      # pick court and time
      f = @b.frame(:name => "mainFrame").frame(:name => "bottom")
      tbody = f.table.tbody
      if reservation.court == "Center"
        court = tbody.img(:title => /Center Court is Available for Block Schedule from #{reservation.time} to .*/)
        if not court.exists?
          court = tbody.img(:title => /Center Court is Available at #{reservation.time}/)
        end
      else
        court = tbody.img(:title => /Court #{reservation.court} is Available for Block Schedule from #{reservation.time} to .*/)
        if not court.exists?
          court = tbody.img(:title => /Court #{reservation.court} is Available at #{reservation.time}/)
        end
      end

      if court.exists?
        @log.debug "About to schedule Court " + reservation.court + " @ " + reservation.time + " on " + dateStr + " for " + name
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
      else
        @log.warn "Court " + reservation.court + " is not available @ " + reservation.time
      end

      get_existing_reservations
    rescue
      retry
    end
  end

  def can_make_reservation?(reservation)
    begin
      if not @days.include?(@date.wday)
        @log.warn @name + " does not schedule on " + @date.strftime('%A') + "s"
        return false
      end
      if @reservations.size >= 6
        @log.warn @name + " already has 2 court reservations, which is the max per day"
        return false
      end
      for existingReservation in @reservations
        if existingReservation.time == reservation.time
          @log.warn @name + " already has a court reservation that overlaps with " + reservation.time
          return false
        end

        time = Time.parse(existingReservation.time) + 30*60
        if time.strftime('%I:%M%p') == reservation.time
          @log.warn @name + " already has a court reservation that overlaps with " + reservation.time
          return false
        end

        time = Time.parse(reservation.time) + 90*60
        if existingReservation.time == time.strftime('%I:%M%p')
          @log.warn @name + " already has a court reservation that overlaps with " + reservation.time
          return false
        end
      end
      return true
    rescue
      retry
    end
  end

  def get_available_courts
  begin
      times = Array.new
      if @date.sunday? or @date.saturday?
        times << "09:00AM" << "10:30AM"
      else
        times << "05:30PM" << "06:00PM" << "07:00PM"
      end

      available_courts = Hash.new

      f = @b.frame(:name => "mainFrame").frame(:name => "bottom")
      tbody = f.table.tbody
      for time in times
        @log.debug "Checking for courts @ " + time
        courts = Hash.new
        for image in tbody.imgs(:title => /is Available .* from #{time}/)
          m = /(Center) Court is Available .* from (.*) to/.match(image.title)
          if m == nil or m.captures.size != 2
            m = /Court (\d\d) is Available .* from (.*) to/.match(image.title)
          end
          if m and m.captures.size == 2
            court = m.captures[0]
            start_time = m.captures[1]

            if not courts.has_key?(court)
              courts[court] = 1
            else
              courts[court] += 1
            end

            if courts[court] == 3
              @log.info court + " is Available @ " + start_time

              if start_time == "06:00PM"
                key = "05:30PM"
              else
                key = start_time
              end

              if not available_courts.has_key?(key)
                available_courts[key] = Array.new
              end
              available_courts[key] << CourtReservation.new(court, start_time)
            end
          end
        end
      end
      available_courts
    rescue
      retry
    end
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

          if not reservation_exists?(court, time)
            @log.info @name + " has Court " + court + " @ " + time + " on " + dateStr
            @reservations << CourtReservation.new(court, time)
          end
        end
      end
      @reservations.size > num_previous_reservations
    rescue
      retry
    end
  end

  def reservation_exists?(court, time)
    for existingReservation in @reservations
      if existingReservation.court == court and existingReservation.time == time
        return true
      end
    end
    false
  end

  def logout
    @b.close
  end

  def dateStr
    @date.strftime('%m/%d/%Y')
  end
end
