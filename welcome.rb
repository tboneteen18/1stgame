require 'gosu'
require 'socket'
require 'thread'
require 'json'

$my_position_lock = Mutex.new
$other_position_lock = Mutex.new
$x = $y = $angle = 0
$id = 0
$hash = Hash.new

module ZOrder
  Background, Stars, Player, UI = *0..3
end

class Player
  attr_reader :x, :y, :angle
  @@image = Gosu::Image.new("media/Starfighter.bmp")
  @@beep = Gosu::Sample.new("media/Beep.wav")

  def initialize
    @x = @y = @vel_x = @vel_y = @angle = 0.0
    @score = 0
  end

  def warp(x, y, rot)
    @x, @y, @angle = x, y, rot
  end

  def turn_left
    @angle -= 4.5
  end

  def turn_right
    @angle += 4.5
  end

  def accelerate
    @vel_x += Gosu::offset_x(@angle, 0.5)
    @vel_y += Gosu::offset_y(@angle, 0.5)
  end

  def move
    @x += @vel_x
    @y += @vel_y
    @x %= 640
    @y %= 480

    @vel_x *= 0.95
    @vel_y *= 0.95
  end

  def draw
    @@image.draw_rot(@x, @y, ZOrder::Player, @angle)
  end

  def score
    @score
  end

  def collect_stars(stars)
    stars.reject! do |star|
      if Gosu::distance(@x, @y, star.x, star.y) < 35 then
        @score += 10
        @@beep.play
        true
      else
        false
      end
    end
  end
end

class Star
  attr_reader :x, :y

  def initialize(animation)
    @animation = animation
    @color = Gosu::Color.new(0xff_000000)
    @color.red = rand(256 - 40) + 40
    @color.green = rand(256 - 40) + 40
    @color.blue = rand(256 - 40) + 40
    @x = rand * 640
    @y = rand * 480
  end

  def draw
    img = @animation[Gosu::milliseconds / 100 % @animation.size];
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0,
        ZOrder::Stars, 1, 1, @color, :add)
  end
end

class GameWindow < Gosu::Window
  def initialize
    super 640, 480

    Thread.new {
      x = 0
      y = 0
      s = TCPSocket.new 'localhost', 2000
      begin
        s.puts "i"
        $id = s.gets.chomp
        puts "Connected to server. Got ID: #{$id} bby"
        loop{
          me = 0
          $my_position_lock.synchronize {
            me = {id: $id, x: "#{$x}", y: "#{$y}", rot: "#{$angle}"}
          }
          s.puts(me.to_json)
          temp = JSON.parse(s.gets)
          $other_position_lock.synchronize {
            $hash = temp
          }
        }
      ensure
        s.close
      end
    }


    self.caption = "1st game"

    @background_image = Gosu::Image.new("media/Space.png", :tileable => true)

    @player = Player.new
    @player.warp(320, 240, 0)

    @star_anim = Gosu::Image::load_tiles("media/Star.png", 25, 25)
    @stars = Array.new

    @font = Gosu::Font.new(20)
  end

  def update
    if Gosu::button_down? Gosu::KbLeft or Gosu::button_down? Gosu::GpLeft then
      @player.turn_left
    end
    if Gosu::button_down? Gosu::KbRight or Gosu::button_down? Gosu::GpRight then
      @player.turn_right
    end
    if Gosu::button_down? Gosu::KbUp or Gosu::button_down? Gosu::GpButton0 then
      @player.accelerate
    end
    @player.move
    got_lock = $my_position_lock.try_lock
    if got_lock then
      $x = @player.x
      $y = @player.y
      # puts "printing angle #{@player.angle}"
      $angle = @player.angle
      $my_position_lock.unlock
    end
    @player.collect_stars(@stars)
    if rand(100) < 4 and @stars.size < 25 then
      @stars.push(Star.new(@star_anim))
    end
  end

  def draw
   @background_image.draw(0, 0, ZOrder::Background)
   @player.draw
   @stars.each { |star| star.draw }
   $other_position_lock.synchronize {
     $hash.each do |id, pos|
       if id != $id then
         player = Player.new
         player.warp(pos[0].to_f, pos[1].to_f, pos[2].to_f)
         player.draw
       end
     end
   }
   @font.draw("Score: #{@player.score}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
  end

  def button_down(id)
    if id == Gosu::KbEscape
      close
    end
  end
end

window = GameWindow.new
window.show
