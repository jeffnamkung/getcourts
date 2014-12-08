require_relative 'log'

require 'pp'
require 'rmeetup'

module RMeetup
  module Poster
    class Event < Base
      attr_accessor :id
      def initialize
        @type = :event
      end

      # Turn the result hash into a Comment Class
      def format_result(result)
        RMeetup::Type::Event.new(result)
      end

      protected
      def base_url
        "https://api.meetup.com/2/#{@type}/#{@id}/"
      end
    end
  end

  class Client
    def post(type, id, options = {})
      poster = RMeetup::Poster.for(type)
      poster.id = id
      poster.post options.merge(auth)
    end
  end
end

class MeetupUpdater
  def initialize(meetup_conf)
    @client = RMeetup::Client.new do |config|
      config.api_key = meetup_conf[:api_key]
    end
    @event_options = {
      :member_id => meetup_conf[:member_id],
      :group_id => meetup_conf[:group_id],
      :venue_id => meetup_conf[:venue_id]
    }
  end

  def update_meetup(date, courts_by_time)
    @event_options[:time] = "%d,%d" % [date.to_time.to_i * 1000, (date + 1).to_time.to_i * 1000]

    @client.fetch(:events, @event_options).each do |result|
      # Do something with the result
      find_us = how_to_find_us(courts_by_time)
      Log.info find_us
      @client.post(:event, result.event['id'], {
          :how_to_find_us => find_us
      })
      break
    end
  end

  private

  def how_to_find_us(courts_by_time)
    courts_by_time.sort.map { |time, courts|
      courts.map { |court|
        court.short_name
      }.join(',') + '@' + time.strftime('%I:%M%p')
    }.join('. ')
  end
end