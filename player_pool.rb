require_relative 'player'

class PlayerPool
  def initialize(config, log)
    @players = []

    config.each do |player_config|
      player = Player.new(player_config, log)

      if player.days.include?(player.date.wday)
        @players << player
      else
        log.warn player.username + " does not schedule on " + player.date.strftime('%A') + "s"
      end
    end
  end

  def players
    @players
  end

  def have_players?
    not @players.empty?
  end

  def admin
    @players[0]
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
end