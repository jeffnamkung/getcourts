require 'date'
require 'time'

class Player
  attr_reader :username
  attr_reader :date
  attr_reader :name
  attr_reader :days

  def initialize(attributes, date)
    @username = attributes[:username]
    @password = attributes[:password]
    @date = date
    @days = Set.new
    for day in attributes[:days_available]
      @days.add Date.parse(day).wday
    end
  end

  def reserve_court(reservation)
    begin
      login

      get_existing_reservations(reservation)

      if reservation.filled?
        logout
        return true
      end

      pick_base_court

      if select_time(reservation.start_time)
        reservation.court_preference.each do |court|
          if select_court(court)
            reservation.reserve_court(court)
            logout
            return true
          end
        end
      end

      logout
      false
    rescue Exception => exception
      Log.warn exception.message
      Log.warn exception.backtrace.inspect
      logout
    end
  end

  def main_frame
    @b.frame(:name => "mainFrame")
  end

  def middle_frame
    main_frame.frame(:name => "middle")
  end

  def bottom_frame
    main_frame.frame(:name => "bottom")
  end

  def pick_base_court
    tbody = bottom_frame.table.tbody
    court = tbody.img(:title => /Center Court is Available at 06:00AM/)
    court.click
  end

  def select_time(start_time)
    time = start_time.strftime('%I:%M%p')
    s = main_frame.select(:name => "cmbstr")
    raise ArgumentError, time + ' time slot is not available' unless s.include?(time)
    s.select(time)
  end

  def select_court(court)
    s = main_frame.select(:name => "cmbres")
    if s.include?(court.long_name)
      s.select(court.long_name)
      return schedule_court unless error?
    end
    false
  end

  def schedule_court
    players = main_frame.text_fields(:name => "txtPname")
    players[1].set 'Will Fill'
    players[2].click

    @b.alert.ok
    main_frame.img(:name => 'schedule').click
    not error?
  end

  def error?
    main_frame.font(:color => "blue").exists?
  end

  def logout
    @b.close
  end

  def get_existing_reservations(reservation)
    tbody = bottom_frame.table.tbody
    for image in tbody.imgs(:title => /Open Play .* for #{@name}/)
      m = /Open Play on CT(.*), for #{@name}, .* scheduled at (.*)/.match(image.title)
      if m and m.captures.size == 2
        court = Court.new(m.captures[0])
        time = m.captures[1]
        start_time = Time.parse(time)

        if reservation.start_time == start_time
          if reservation.reserve_court(court)
            Log.info @name + " already has " + court.long_name + " @ " + time
          end
        end
      end
    end
  end

  def dateStr
    @date.strftime('%m/%d/%Y')
  end

  def login
    begin
      num_retries = 0
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
      @name = @b.frame(:name => "header").table.table.font(:color => "white").text

      # pick date
      pick_date(@date)
      true
    rescue Exception => exception
      Log.warn exception.message
      Log.warn exception.backtrace.inspect
      @b.close
      num_retries += 1
      if num_retries < 3
        retry
      else
        false
      end
    end
  end

  def pick_date(date)
    date_str = "%d/%d/%d" % [date.month, date.day, date.year]
    form = middle_frame.form(:id => "frmSch")
    if date.month > Date.today.month
      next_month_link = "/application/esch_ematch/testcal.asp?month=%d&year=%d" % [date.month, date.year]
      form.a(:href => next_month_link).click
    end
    form = middle_frame.form(:id => "frmSch")
    form.a(:href => "javascript:setDate('" + date_str + "')").click
  end
end
