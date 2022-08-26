require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do 
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, 'secret'
end

before do
  @storage = SessionPersistence.new(session)
end

helpers do 
  
  # Return an array of error msgs if the name is invalid, otherwise return nil.
  def error_for_list_name(name)
    lists = @storage.all_lists
    errors = []

    if !(1..100).cover?(name.length)
      errors << "The list name must be between 1 and 100 characters long."
    elsif lists.any? { |list| list[:name].downcase == name.downcase }
      errors << "There is already a list by that name."
    end
    errors.empty? ? nil : errors
  end

  # Return an array of error messages if the todo name is invalid,
  # otherwise return nil
  def error_for_todo(name)
    errors = []
    if !(1..100).cover?(name.length)
      errors << "The todo must be between 1 and 100 characters long."
    end
    errors.empty? ? nil : errors
  end

  # Returns true if all todos are marked as complete, false otherwise
  def all_todos_complete?(todos)
    todos.all? { |todo| todo[:completed]}
  end

  # Returns 'complete' if list has at least one todo and all todos 
  # are marked completed
  def list_completion_status(list)
    "complete" if !list[:todos].empty? && all_todos_complete?(list[:todos])
  end

  # Returns true if a list has all of it's todos marked as complete
  def list_complete?(list)
    list_completion_status(list) == 'complete'
  end

  def load_list(id)
    list = @storage.find_list(id)
    return list if list

    session[:error] = ["The specified list was not found."]
    redirect "/lists"
  end

  # Sort list order by completion status - 'completed' at the bottom
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition do |list|
      list_complete?(list)
    end
    
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  # sort todos order by completion status - 'completed' at bottom
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  # Return the ratio of uncompleted_todos/total_todos
  def todo_completion_ratio(todos)
    todos_left_to_do = todos.count { |todo| todo[:completed] == false }
    total_todo_count = todos.count
    "#{todos_left_to_do}/#{total_todo_count}"
  end

  def todo_completion_status(todo)
    "complete" if todo[:completed]
  end
end

def select_by_id(collection, id)
  collection.find { |member| member[:id] == id }
end


class SessionPersistence
  
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_element_id(@session[:lists])
    @session[:lists] << {id: id, name: list_name, todos: [] }
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    todo_id = next_element_id(list[:todos])
    list[:todos] << {id: todo_id, name: todo_name, completed: false}
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def mark_all_todos_as_completed(list_id)
    list = find_list(list_id)
    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  def update_list_name(id, new_name)
    list = find_list(id)
    list[:name] = new_name
  end

  def update_todo_status(list_id, todo_id, completion_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = completion_status
  end

  private 

  def next_element_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end
end

##Routes

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do 
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Create a new list
post "/lists" do 
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    @storage[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Render the new list form
get "/lists/new" do 
  erb :new_list, layout: :layout
end

# Display todos for a single list
get "/lists/:list_id" do
  @lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :list, layout: :layout
end

# Edit an existing todo 
get "/lists/:list_id/edit" do 
  @lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:list_id" do 
  list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = "The list name has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a list from the session :lists
post "/lists/:list_id/delete" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @storage.delete_list(@list_id)

  session[:success] = "The list has been deleted."

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
        
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item from a list
post "/lists/:list_id/todos/:todo_id/delete" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @storage.delete_todo_from_list(@list_id, todo_id)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(@list_id, todo_id, is_completed)
  

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos in a list complete
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  @storage.mark_all_todos_as_completed(@list_id)
  
  session[:success] = "All todos for list \"#{@list[:name]}\" were marked complete."
  redirect "/lists/#{@list_id}"
end



