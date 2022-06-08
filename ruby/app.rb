require 'sinatra/json'
require 'active_support'
require 'active_support/json'
require 'active_support/time'
require_relative 'db'
require "date"

Time.zone = 'UTC'

class App < Sinatra::Base
  enable :logging

  set :session_secret, 'tagomoris'
  set :sessions, key: 'session_isucon2021_prior', expire_after: 3600
  set :show_exceptions, false
  set :public_folder, './public'
  set :json_encoder, ActiveSupport::JSON

  helpers do
    def db
      DB.connection
    end

    def transaction(name = :default, &block)
      DB.transaction(name, &block)
    end

    def generate_id(table, tx)
      
       tx.xquery("SELECT count(id) FROM `#{table}`" ).first +1
       
    end

    def required_login!
      halt(401, JSON.generate(error: 'login required')) if current_user.nil?
    end

    def required_staff_login!
      halt(401, JSON.generate(error: 'login required')) if current_user.nil? || !current_user[:staff]
    end

    def current_user
      db.xquery('SELECT * FROM `users` WHERE `id` = ? LIMIT 1', session[:user_id]).first
    end

    def get_reservations(schedule)
      reservations = db.xquery('SELECT * FROM `reservations` WHERE `schedule_id` = ?', schedule[:id]).map do |reservation|
        reservation[:user] = get_user(reservation[:user_id])
        reservation[:id] = reservation[:id].to_s
        reservation
      end
      schedule[:id] = schedule[:id].to_s
      schedule[:reservations] = reservations
      schedule[:reserved] = reservations.size
    end

    def get_reservations_count(schedule)
      reservations = db.xquery('SELECT * FROM `reservations` WHERE `schedule_id` = ?', schedule[:id].to_i)
      schedule[:reserved] = reservations.size
    end

    def get_user(id)
      user = db.xquery('SELECT * FROM `users` WHERE `id` = ?', id).first
      user[:email] = '' if !current_user || !current_user[:staff]
      user[:id]  = user[:id].to_s
      user
    end
  end

  error do
    err = env['sinatra.error']
    $stderr.puts err.full_message
    halt 500, JSON.generate(error: err.message)
  end

  post '/initialize' do
    transaction do |tx|
      tx.query('TRUNCATE `reservations`')
      tx.query('TRUNCATE `schedules`')
      tx.query('TRUNCATE `users`')

      tx.xquery('INSERT INTO `users` (`email`, `nickname`, `staff`, `created_at`) VALUES ( ?, ?, true, NOW(6))', 'isucon2021_prior@isucon.net', 'isucon')
    end

    json(language: 'ruby')
  end

  get '/api/session' do
    json(current_user)
  end

  post '/api/signup' do

    nickname = ''

    user = transaction do |tx|
      email = params[:email]
      nickname = params[:nickname]
      tx.xquery('INSERT INTO `users` (`email`, `nickname`, `created_at`) VALUES (?, ?, NOW(6))', email, nickname)
      a =  tx.xquery('SELECT id,`created_at` FROM `users` WHERE `email` = ? ', email)
created_at =a.first[:created_at]
id = a.first[:id]
      { id: id.to_s, email: email, nickname: nickname, created_at: created_at }
    end

    json(user)
  end

  post '/api/login' do
    email = params[:email]

    user = db.xquery('SELECT `id`, `nickname` FROM `users` WHERE `email` = ? ', email).first

    if user
      session[:user_id] = user[:id]
      json({ id: current_user[:id].to_s, email: current_user[:email], nickname: current_user[:nickname], created_at: current_user[:created_at] })
    else
      session[:user_id] = nil
      halt 403, JSON.generate({ error: 'login failed' })
    end
  end

  post '/api/schedules' do 
    required_staff_login!

    transaction do |tx|
      title = params[:title].to_s
      capacity = params[:capacity].to_i
      d = DateTime.now.strftime("%Y-%m-%d %H:%M:%S.000000")

      id = tx.query("SELECT count(id) as count FROM `schedules`" ).first[:count] +1
      tx.xquery('INSERT INTO `schedules` ( id,`title`, `capacity`, `created_at`) VALUES (?,?, ?, ?)', id, title, capacity,d)
      created_at = tx.xquery('SELECT `created_at` FROM `schedules` WHERE `id` = ?', id).first[:created_at]


      json({ id: id.to_s, title: title, capacity: capacity, created_at: created_at })
    end
  end

  post '/api/reservations' do
    required_login!

    transaction do |tx|
      schedule_id = params[:schedule_id].to_i
      user_id = current_user[:id].to_i

      halt(403, JSON.generate(error: 'schedule not found')) if tx.xquery('SELECT 1 FROM `schedules` WHERE `id` = ? LIMIT 1 FOR UPDATE', schedule_id).first.nil?
      halt(403, JSON.generate(error: 'user not found')) unless tx.xquery('SELECT 1 FROM `users` WHERE `id` = ? LIMIT 1', user_id).first
      halt(403, JSON.generate(error: 'already taken')) if tx.xquery('SELECT 1 FROM `reservations` WHERE `schedule_id` = ? AND `user_id` = ? LIMIT 1', schedule_id, user_id).first

      capacity = tx.xquery('SELECT `capacity` FROM `schedules` WHERE `id` = ? LIMIT 1', schedule_id).first[:capacity]
      reserved = 0
      tx.xquery('SELECT * FROM `reservations` WHERE `schedule_id` = ?', schedule_id).each do
        reserved += 1
      end

      halt(403, JSON.generate(error: 'capacity is already full')) if reserved >= capacity
      id = tx.query("SELECT count(id) as count FROM `reservations`" ).first[:count] +1
      tx.xquery('INSERT INTO `reservations` (id,`schedule_id`, `user_id`, `created_at`) VALUES (?,?, ?, NOW(6))',id, schedule_id, user_id)
      created_at = tx.xquery('SELECT `created_at` FROM `reservations` WHERE `id` = ?', id).first[:created_at]

      json({ id: id.to_s, schedule_id: schedule_id, user_id: user_id, created_at: created_at})
    end
  end

  get '/api/schedules' do
    schedules = db.xquery('SELECT CAST(id AS CHAR) as id,title,capacity,created_at FROM `schedules` ORDER BY `id` DESC');
    schedules.each do |schedule|
      get_reservations_count(schedule)
    end

    json(schedules.to_a)
  end

  get '/api/schedules/:id' do
    id = params[:id]
    schedule = db.xquery('SELECT * FROM `schedules` WHERE id = ? LIMIT 1', id).first
    halt(404, {}) unless schedule

    get_reservations(schedule)

    json(schedule)
  end

  get '*' do
    File.read(File.join('public', 'index.html'))
  end
end
