#!/usr/bin/env ruby

require 'optparse'
require 'trello'
require 'yaml'

config_file = File.expand_path('../settings.yml', __FILE__)

unless File.exists?(config_file)
  puts <<HELP
#{config_file} missing. Use #{config_file}.example as example and fill
in the correct data
HELP
  exit 1
end

def event_date(month_date)
  event_day = 3 # Thursday
  end_of_month = month_date.end_of_month
  event_date = end_of_month - ((end_of_month.days_to_week_start - event_day) % 7).days
  return event_date
end

def postpone(card)
  if card.due && card.due < Time.now
    postpone_for = event_date(card.due + 4.weeks) - event_date(card.due)
    card.due += postpone_for
    card.save
  end
end

def clear_checklists(card)
  card.checklists.each do |checklist|
    checklist.items.each do |item|
      path = "/cards/#{card.id}/checklist/#{checklist.id}/checkItem/#{item.id}"
      card.client.put(path, {"state" => "incomplete"})
    end
  end
end

config = YAML.load_file(config_file)

Trello.configure do |c|
  c.consumer_key    = config['consumer_key']
  c.consumer_secret = config['consumer_secret']
  c.oauth_token     = config['oauth_token']
end

options = {}
parser = OptionParser.new do |opts|
  opts.banner = <<BANNER
Script for reseting trello board for periodic events planning

Usage: trello-reset.rb -b BOARD_ID
BANNER

  opts.on("-b BOARD_ID", "board id to be reset") do |board|
    options[:board] = board
  end
end

parser.parse!

unless options[:board]
  puts parser
  exit 2
end

board = Trello::Board.find(options[:board])

starting_list = board.lists.first


board.cards.each do |card|
  card.move_to_list(starting_list)

  postpone(card)
  clear_checklists(card)
end
