#!/usr/bin/ruby
#
# serial2mqtt.rb
# 
# Usage:
#   $ gem install mqtt serialport
#   $ git clone https://github.com/yoggy/mqtt-serial.git
#   $ cd mqtt-serial
#   $ ./serial2mqtt.rb
#   
#   usage : ./serial2mqtt.rb serialport bps host port publish_topic
#
#   example :
#       $ ./serial2mqtt.rb /dev/ttyUSB0 9600 localhost 1883 topic/recv
#
#   $ ./serial2mqtt.rb /dev/ttyAMA0 115200 iot.eclipse.org 1883 serial2mqtt/recv
#
# License:
#   Copyright (c) 2018 yoggy <yoggy0@gmail.com>
#   Released under the MIT license
#   http://opensource.org/licenses/mit-license.php;
#

require 'serialport'
require 'mqtt'
require 'pp'
require 'ostruct'
require 'logger'

$stdout.sync = true
$log = Logger.new(STDOUT)
$conf = OpenStruct.new

def usage
  puts <<-EOS
usage : #{$0} serialport bps host port publish_topic

example :
    $ #{$0} /dev/ttyUSB0 9600 localhost 1883 topic/recv
EOS
  exit(1)
end

def bruteforce_open(base_path)
  sp = nil
  idx = 0
  begin
    path = "#{base_path}#{idx}"
    $log.info "open : trying...path=#{path}"
    sp = SerialPort.new(path, $conf.bps, 8, 1, 0)
    $log.info "open : success...path=#{path}"
  rescue
    sleep 0.5
    idx += 1
    retry if idx < 10
  end
  sp
end

def read_loop
  $log.info "open : serialport=#{$conf.dev}, bps=#{$conf.bps}"
  if $conf.dev == "/dev/ttyUSB"
    sp = bruteforce_open($conf.dev)
  else
    sp = SerialPort.new($conf.dev, $conf.bps, 8, 1, 0)
  end
  buf = ""

  MQTT::Client.connect(:host=>$conf.host, :port=>$conf.port) do |mqtt|
    $log.info "mqtt connected! : host=#{$conf.host}, port=#{$conf.port}"
    loop do
      c = sp.getc.force_encoding("US-ASCII")
      buf += c

      if c.ord == 0x0a # CR(0x0d) + LF(0x0a)
        $log.info "mqtt publish : topic=#{$conf.topic}, payload=#{buf}"
        mqtt.publish($conf.topic, buf)
        buf = ""
      end
    end
  end
end

if __FILE__ == $0 
  usage if ARGV.size != 5

  $conf.dev   = ARGV[0]
  $conf.bps   = ARGV[1].to_i
  $conf.host  = ARGV[2]
  $conf.port  = ARGV[3].to_i
  $conf.topic = ARGV[4]

  $log.info "conf=" + $conf.pretty_inspect

  loop do
    begin
      read_loop
    rescue Exception => e
      $log.error e.message
      $log.error e.backtrace
      $log.info "restarting after 10 seconds..."
      sleep 10
    end
  end
end

