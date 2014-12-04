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

  def fill_reservations
    while have_players?
      reservation = DailyReservation.next_reservation
      if reservation.nil?
        break
      end
      Log.info("Finding " + reservation.to_s)
      @players.each do |player|
        if player.reserve_court(reservation)
          if reservation.filled?
            break
          end
        end
      end

      if reservation.filled?
        Log.info("Filled " + reservation.to_s)
      else
        Log.warn("Unable to fill " + reservation.to_s)
      end
      DailyReservation.remove(reservation)
    end
  end
end