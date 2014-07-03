############################################################################
#
#   BotSpade
#
#   Copyright (c) 2014 by Jason Preston
#   A Twitch Chat Bot
#   Version 0.4 - 6/26/2014
#
#   Feel free to use for your own nefarious purposes

require 'isaac'
require 'json'
require 'sqlite3'

require "./botconfig"

require './botlite'

############################################################################
#
# Helpers
#

helpers do

  # An expensive way to pretend like I have a daemon
  # check for latent processes and execute them
  def fake_daemon
    msg channel, Time.now.utc
    msg channel, @betstimer
    if Time.now.utc > @betstimer + 10 && @betsopen == TRUE #300
      @betsopen = FALSE
      msg channel, "Bets are now closed. GL."
    end
  end

  def save_data
    msg channel, "success" if File.write('pointsdb.txt', @pointsdb.to_json) && File.write('checkindb.txt', @checkindb.to_json) && File.write('viewerdb.txt', @viewerdb.to_json) && File.write('gamesdb.txt', @gamesdb.to_json)
  end

  def save_data_silent
    File.write('pointsdb.txt', @pointsdb.to_json) && File.write('checkindb.txt', @checkindb.to_json) && File.write('viewerdb.txt', @viewerdb.to_json) && File.write('gamesdb.txt', @gamesdb.to_json)
    fake_daemon
  end

  def take_points(nick, points)
    if @pointsdb.key?(nick)
      @pointsdb[nick] = @pointsdb[nick] - points
      save_data_silent
    else
      msg channel, "#{nick} does not have any Spade Points!"
    end
  end

  def give_points(nick, points)
    if @pointsdb.key?(nick)
      @pointsdb[nick] = @pointsdb[nick] + points
    else
      @pointsdb[nick] = points
    end
    save_data_silent
  end

  def person_has_enough_points(person, points_required)
    if @pointsdb.key?(person)
      points_available = @pointsdb[person]
      if points_available < points_required
        points_check_result = FALSE
      else
        points_check_result = TRUE
      end
    else
      points_check_result = FALSE
    end
    return points_check_result
  end

  def pretty_uptime
    if @stream_start_time == "none"
      return 0
    else
      uptime = Time.now.utc.to_i - @stream_start_time.to_i
      if uptime < 60
        return "#{uptime} seconds"
      elsif uptime > 60 && uptime < 3600
        uptime_in_minutes = uptime / 60
        return "#{uptime_in_minutes} minutes"
      elsif uptime > 3600 && uptime < 86400
        uptime_in_hours = uptime / 3600
        calc_remainder = uptime_in_hours.to_i * 3600
        remainder = uptime - calc_remainder
        remainder_in_minutes = remainder / 60
        return "#{uptime_in_hours.to_i} hours and #{remainder_in_minutes} minutes"
      else
        return "#{uptime} seconds"
      end
    end
  end

end


############################################################################
#
# Basic Call & Response presets
#

on :channel, /^!changelog/i do
  msg channel, "v0.5: Bets now toggle off automatically. Added !uptime. Fixed bug in !give and merged Etheco's code (thanks Etheco!)"
end

on :channel, /^!beard/i do
  msg channel, "#{@botmaster} wears a beard because it's awesome. He trims with a Panasonic ER-GB40 and shaves the lower whiskers with a safety razor, which is badass."
end

on :channel, /^!commands/i do
  msg channel, "Some commands include: !points, !bet, !top, !leaderboard, !changelog, !points, !welcome, !shave, !getpoints, !minispade, !twitter, !spade, !tweet, !follow, !help. There are others."
end

on :channel, /^!shave/i do
  msg channel, "If the stream reaches 75 concurrent viewers, Spade will shave his beard off. On stream."
end

on :channel, /^!welcome/i do
  msg channel, "Welcome to #{@botmaster}'s stream! Don't forget to !checkin for #{@botmaster} Points. Type !help for more options."
  fake_daemon
end

on :channel, /^!startstream/i do
  if nick == "watchspade"
    @stream_start_time = Time.now.utc
    msg channel, "Stream started."
  end
end

on :channel, /^!endstream/i do
  if nick == "watchspade"
    @stream_start_time = "none"
    msg channel, "Stream ended."
  end
end

on :channel, /^!uptime/i do
  @uptime_for_display = pretty_uptime
  if @uptime_for_display != 0
    msg channel, "#{@botmaster} has been streaming for #{@uptime_for_display}."
  else
    msg channel, "Whoops, #{@botmaster} forgot to start the timer! Starting it now..."
    @stream_start_time = Time.now.utc
  end
end

on :channel, /^!debug/i do
  if nick == "watchspade"
    msg channel, "#{@stream_start_time}"
  end
end

on :channel, /^!getpoints/i do
  msg channel, "You can get #{@botmaster} Points by checking in (!checkin), donating, tweeting (!tweet), & winning bets (!bet for usage). Or you can be given points (!give)."
end

on :channel, /^!minispade/i do
  msg channel, "Spade has a just-about two year old son: minispade."
end

on :channel, /^!follow/i do
  msg channel, "Earn five points for following the stream (first time only!!), five points for following @jasonp on Twitter (first time only!!)"
end

on :channel, /^!twitter/i do
  msg channel, "Spade's twitter is http://twitter.com/jasonp"
end

on :channel, /^!tweet/i do
  msg channel, "Earn five points for tweeting: Watching Spade stream some CSGO! http://twitch.tv/watchspade cc @jasonp"
end

on :channel, /^!spade$/i do
  msg channel, "When Alexander Graham Bell invented the telephone, he had three missed calls from Spade."
end

on :channel, /^!spadeout/i do
  if nick == "watchspade"
    @stream_start_time = "none"
  end
  msg channel, "Spaaaaaaaaade out."
end

on :channel, /^!botspade/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss/tie], !checkin, !points, and a few other surprises."
end

on :channel, /^!help/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss/tie], !checkin, !points, and a few other surprises."
end

on :channel, /^!points/i do
  if @pointsdb.key?(nick)
    userpoints = @pointsdb[nick].to_s
    msg channel, "#{nick} has #{userpoints} #{@botmaster} Points."
  else
    msg channel, "Sorry, it doesn't look like you have any Spade Points!"
  end
  fake_daemon
end

on :channel, /^!leaderboard/i do
  protoboard = @pointsdb.sort_by { |nick, points| points }
  leaderboard = protoboard.reverse
  msg channel, "Leaderboard: #{leaderboard[0]}, #{leaderboard[1]}, #{leaderboard[2]}, #{leaderboard[3]}, #{leaderboard[4]}"
  fake_daemon
end

on :channel, /^!top/i do
  topviewers = @checkindb.sort_by { |nick, checkin_array| checkin_array.count }
  top = topviewers.reverse
  string = []
  5.times do |i|
    amount = top[i.to_i][1].count
    name = top[i.to_i][0]
    string << name << amount
  end
  msg channel, "Top Viewers by !checkins: #{string[0]} (#{string[1]} checkins), #{string[2]} (#{string[3]} checkins), #{string[4]} (#{string[5]} checkins)"
  fake_daemon
end

on :channel, /^!statsme/i do
  user_record = @checkindb[nick] if @checkindb.key?(nick)
  checkins = user_record.count
  msg channel, "#{nick}: #{checkins} checkins!"
end

on :channel, /^!stats$/i do
  wincount = @gamesdb["wincount"]
  losscount = @gamesdb["losscount"]
  tiecount = @gamesdb["tiecount"]
  wlratio = wincount.to_f / losscount.to_f
  msg channel, "#{@botmaster} has reported #{wincount} wins, #{losscount} losses, and #{tiecount} ties. W/L ratio: #{wlratio}"
end

############################################################################
#
# Viewer DB
#

on :channel, /^!update (.*) (.*) (.*)/i do |first, second, last|
  person = first.downcase
  attribute = second.downcase
  value = last.downcase
  if person == nick
    if @viewerdb.key?(person)
      person_hash = @viewerdb[person]
      person_hash[attribute] = value
      @viewerdb[person] = person_hash
      msg channel, "#{attribute} updated for #{nick}"
    else
      person_hash = {}
      person_hash[attribute] = value
      @viewerdb[person] = person_hash
      msg channel, "#{attribute} updated for #{nick}"
    end
    save_data_silent
  end
end

on :channel, /^!update$/i do
  msg channel, "Add info to your file in the Viewer db. Usage: !update [username] [attribute] [value], e.g. !update watchspade country USA"
end

on :channel, /^!lookup (.*) (.*)/i do |first, last|
  person = first.downcase
  attribute = last.downcase
  if @viewerdb.key?(person)
    if attribute == "index"
      person_hash = @viewerdb[person]
      person_array = person_hash.keys
      msg channel, "#{person}: #{person_array}"
    else
      person_hash = @viewerdb[person]
      lookup_value = person_hash[attribute]
      msg channel, "#{person}: #{lookup_value}"
    end
  else
    msg channel, "Sorry, nothing in the viewer database for that!"
  end
end

on :channel, /^!lookup$/i do
  msg channel, "Lookup other viewers. Usage: !lookup [username] [attribute]. You can also do !lookup [username] index to see what attributes are available."
end

on :channel, /^!remove (.*) (.*)/i do |first, second|
  person = first.downcase
  attribute = second.downcase
  if person == nick
    if @viewerdb.key?(person)
      person_hash = @viewerdb[person]
      person_hash.delete(attribute)
      @viewerdb[person] = person_hash
      msg channel, "#{attribute} removed for #{nick}"
    else
      msg channle, "#{nick}: I don't see anything to remove!"
    end
    save_data_silent
  end
end

on :channel, /^!remove$/i do
  msg channel, "Remove info from your file in the Viewer db. Usage: !remove [username] [attribute], e.g. !remove watchspade country"
end


############################################################################
#
# Dealing with betting
#

on :channel, /^!bet$/i do
  bet_status = ""
  if @betsopen == TRUE
    bet_status = "(Bets are open right now)"
  else
    bet_status = "(Bets are closed right now)"
  end
  msg channel, "Usage: !bet [points] [win/loss/tie] e.g. !bet 15 loss #{bet_status}"
  fake_daemon
end

on :channel, /^!bet (.*) (.*)/i do |first, last|
  bet_amount = first.to_i
  win_loss = last.downcase
  if @betsopen == TRUE
    if first.to_f < 1
      msg channel, "Sorry, you can't bet in fractions/phrases... whole numbers only!"
    else
      if person_has_enough_points(nick, bet_amount)
        if @betsdb[nick]
          msg channel, "#{nick}: Bet Refused, You have already bet"
        else
          @betsdb[nick] = [bet_amount, win_loss]
          take_points(nick, bet_amount)
          msg channel, "#{nick}: Bet recorded."
        end
      else
        msg channel, "Whoops, #{nick} it looks like you don't have enough points!"
      end
    end
  else
    msg channel, "Sorry, bets aren't open right now."
  end
  fake_daemon
end

on :channel, /^!reportgame (.*)/i do |first|
  if nick == "watchspade"
    total_won = 0
    winner_count = 0
    if first.downcase == "win"
      @gamesdb[Time.now.utc.to_s] = "win"
      if @gamesdb["wincount"]
        @gamesdb["wincount"] = @gamesdb["wincount"] + 1
      else
        @gamesdb["wincount"] = 1
      end
      @betsdb.keys.each do |bettor|
        bet_amount = @betsdb[bettor][0]
        win_loss = @betsdb[bettor][1]
        if win_loss == "win"
          winnings = bet_amount * 2
          total_won = total_won + winnings
          winner_count = winner_count + 1
          give_points(bettor, winnings)
        end
      end
      save_data_silent
    elsif first.downcase == "loss"
      @gamesdb[Time.now.utc.to_s] = "loss"
      if @gamesdb["losscount"]
        @gamesdb["losscount"] = @gamesdb["losscount"] + 1
      else
        @gamesdb["losscount"] = 1
      end
      @betsdb.keys.each do |bettor|
        bet_amount = @betsdb[bettor][0]
        win_loss = @betsdb[bettor][1]
        if win_loss == "loss"
          winnings = bet_amount * 2
          total_won = total_won + winnings
          winner_count = winner_count + 1
          give_points(bettor, winnings)
        end
      end
      save_data_silent
    elsif first.downcase == "tie"
      @gamesdb[Time.now.utc.to_s] = "tie"
      if @gamesdb["tiecount"]
        @gamesdb["tiecount"] = @gamesdb["tiecount"] + 1
      else
        @gamesdb["tiecount"] = 1
      end
      @betsdb.keys.each do |bettor|
        bet_amount = @betsdb[bettor][0]
        win_loss = @betsdb[bettor][1]
        if win_loss == "tie"
          winnings = bet_amount * 2
          total_won = total_won + winnings
          winner_count = winner_count + 1
          give_points(bettor, winnings)
        end
      end
      save_data_silent
    end
    @betsdb = {}
    save_data_silent
    msg channel, "Bets tallied. #{total_won.to_s} #{@botmaster} Points won by #{winner_count.to_s} gambler(s)."
  end
end

on :channel, /^!togglebets/i do
  if nick == "watchspade"
    if @betsopen == FALSE
      @betsopen = TRUE
      @betstimer = Time.now.utc
      msg channel, "Betting is now open for 5 minutes. Place your bets: !bet [points] [win/loss/tie]"
    elsif @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Betting is now closed. GL."
    end
  end
end

#on :channel, /^!1v1$/i do
#  msg channel, "Usage: !1v1 [win/loss] - all 1v1 bets are for 2 points, but cost nothing"
#end

# Method for users to give points to other viewers
# !give user points

on :channel, /^!give (.*) (.*)/i do |first, last|
  person = first.downcase
  points = last.to_i
  if nick == "watchspade"
    give_points(person, points)
    msg channel, "#{nick} has given #{person} #{points} #{@botmaster} Points"
  else
    if @checkindb.key?(nick)
      if person_has_enough_points(nick, points)
          give_points(person, points)
          take_points(nick, points)
          msg channel, "#{nick} has given #{person} #{points} #{@botmaster} Points"
      else
        msg channel, "I'm sorry #{nick}, you don't have enough #{@botmaster} Points!"
      end
    else
      msg channel, "You can only give points to someone who has checked in at least once!"
    end
  end
end

on :channel, /^!give$/i do
  msg channel, "Usage: !give [username] [points]."
end


# Method for Spade to take points from naughty viewers
# !take user points
on :channel, /^!take (.*) (.*)/i do |first, last|
  if nick == "watchspade"
    person = first.downcase
    points = last.to_i
    take_points(person, points)
  end
end

# Method to give points for chat activity
# Check to see if points have been given yet today
on :channel, /^!checkin/i do
  if @checkindb.key?(nick)
    checkin_array = @checkindb[nick]
    last_checkin = checkin_array[-1]
    allowed_checkin = Time.now.utc - 43200
    if last_checkin > allowed_checkin.to_i
      msg channel, "#{nick} checked in already, no #{@botmaster} Points given."
    else
      checkin_array << Time.now.utc.to_i
      @checkindb[nick] = checkin_array
      give_points(nick, 4)
      msg channel, "Thanks for checking in, #{nick}! You have been given 4 #{@botmaster} Points!"
      if checkin_array.count == 50
        msg channel, "#{nick} this is your 50th check-in! You Rock (and get 50 points)"
        give_points(nick, 50)
      end
    end
  else
    checkin_array = []
    checkin_array << Time.now.utc.to_i
    @checkindb[nick] = checkin_array
    give_points(nick, 4)
    msg channel, "Thanks for checking in, #{nick}! You have been given 4 #{@botmaster} Points!"
  end
end

on :channel, /^!savedata/i do
  if nick == "watchspade"
    save_data
  end
end

############################################################################
#
# Referrals
#

on :channel, /^!referredby$/i do
  msg channel, "You & someone new each get 10 #{@botmaster} Points! New viewer must enter: !referredby [your username]"
end

on :channel, /^!referredby (.*)/i do |first|
  referrer = first.downcase
  if @checkindb.key?(nick)
    msg channel, "Hmm, looks like you've checked in here before! Sorry, you only get to be new once!"
  else
    checkin_array = []
    checkin_array << Time.now.utc.to_i
    @checkindb[nick] = checkin_array
    give_points(nick, 14)
    give_points(referrer, 10)
    msg channel, "Welcome #{nick}! You & #{referrer} have been awarded 10 #{@botmaster} Points! You have also been checked in for 4 #{@botmaster} Points."
  end
end

############################################################################
#
# The Spade Points Store
#
#
# This must eventually be re-written as a loop somehow...

on :channel, /^!purchase (.*)/i do |protopurchase|
  purchase = protopurchase.downcase
  if purchase == "fedora"
    if person_has_enough_points(nick, 20)
      take_points(nick, 20)
      msg channel, "#{nick} has forced #{@botmaster} to wear a Fedora for the rest of this stream. [-20sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
    end
  elsif purchase == "bdp"
    if person_has_enough_points(nick, 10)
      take_points(nick, 10)
      msg channel, "#{nick} has demanded that Spade make a Big Dick Play. Here goes nothing. [-10sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
    end
  elsif purchase == "suit"
    if person_has_enough_points(nick, 10)
      take_points(nick, 10)
      msg channel, "#{nick} has bribed Spade to wear a suit for the rest of this stream. Oh boy. [-100sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
    end
  elsif purchase == "menu"
    msg channel, "SpadeStore Menu: !fedora (20sp - Spade wears fedora), !bdp (10sp - Spade tries a big dick play), !suit (100sp - Spade wears a suit)"
  end
end

on :channel, /^!purchase$/i do
  msg channel, "SpadeStore Menu: !fedora (20sp - Spade wears fedora), !bdp (10sp - Spade tries a big dick play), !suit (100sp - Spade wears a suit)"
end

# Elaborate on what you can buy

on :channel, /^!fedora/i do
  msg channel, "You can make #{@botmaster} wear a fedora by spending 20 #{@botmaster} Points. Type !purchase fedora to activate."
end

on :channel, /^!suit/i do
  msg channel, "You can make #{@botmaster} wear a suit by spending 100 #{@botmaster} Points. Type !purchase suit to activate."
end

on :channel, /^!bdp/i do
  msg channel, "BDP stands for Big Dick Play. You can make #{@botmaster} attempt a BDP for 10 points with !purchase bdp"
end



# build functions (helpers) for common DB calls, e.g. if_user_has_checkins(user), etc

# bet on 1v1
# get & set a status message?
# split out a separate file for variables & customization, leave engine in main file
# bet on other aspects: ace, 4k, 3k, 2k, 1k, pistol something, beat average stats, & so on

# week-long lottery type of thing? reward for most check-ins? (I don't track this currently)
# !game starts game of clues with !command subsequent, winner gets 50 points or something.
# refactor / generalize: admins array, make Spade Points a variable, etc.
# !bitcoin / !gaben / !esea / !CEVO / !altpug
# make points given for checkin, etc, variables to be set via chat command via moderators.
# make store modifiable via chat commands?
# old changelog:
# v0.3: Removed points fee on !give. Added !commands command. Can bet on tie. Added !top. Added Viewer DB !lookup & !update
