require_relative 'player'

class PlayerPool
  def initialize(config, date)
    @players = []

    config.each do |player_config|
      player = Player.new(player_config, date)

      if player.days.include?(player.date.wday)
        @players << player
      else
        Log.warn player.username + " does not schedule on " + player.date.strftime('%A') + "s"
      end
    end
  end

  def have_players?
    not @players.empty?
  end

  def get_existing_reservations
    courts_by_time = Hash.new {|h,k| h[k]=[]}
    @players.each do |player|
      player.get_existing_reservations
      player.reservations.each do |reservation|
        courts_by_time[reservation.start_time] << reservation.court
      end
    end
    courts_by_time
  end

  def login
    @players.delete_if { |player| not player.login }
  end

  def logout
    @players.each do |player|
      player.logout
    end
  end

  def find_available_player(start_time)
    @players.each do |player|
      if player.can_make_reservation?(start_time)
        return player
      end
    end
  end

  def fill_reservations
    while DailyReservation.not_done? and have_players?
      reservation = DailyReservation.next_reservation
      Log.info("Finding " + reservation.to_s)
      @players.each do |player|
        if player.reserve_court(reservation)
          if reservation.filled?
            break
          end
        end
      end
    end
  end
end