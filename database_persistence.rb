require "pg"

class DatabasePersistence
  
  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement} : #{params}"
    @db.exec_params(statement, params)
  end

  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)

    
    result.map do |tuple|
      { id: tuple["id"], name: tuple["name"], todos: [] }
    end
  end

  def create_new_list(list_name)
    # id = next_element_id(@session[:lists])
    # @session[:lists] << {id: id, name: list_name, todos: [] }
  end

  def create_new_todo(list_id, todo_name)
    # list = find_list(list_id)
    # todo_id = next_element_id(list[:todos])
    # list[:todos] << {id: todo_id, name: todo_name, completed: false}
  end

  def delete_list(id)
    # @session[:lists].reject! { |list| list[:id] == id }
  end

  def delete_todo_from_list(list_id, todo_id)
    # list = find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, id)

    
    tuple = result.first
    todos = fetch_todos_from_list(tuple["id"])
    { id: tuple["id"], name: tuple["name"], todos: todos }
  end

  def mark_all_todos_as_completed(list_id)
    # list = find_list(list_id)
    # list[:todos].each do |todo|
    #   todo[:completed] = true
    
  end

  def update_list_name(id, new_name)
    # list = find_list(id)
    # list[:name] = new_name
  end

  def update_todo_status(list_id, todo_id, completion_status)
    # list = find_list(list_id)
    # todo = list[:todos].find { |t| t[:id] == todo_id }
    # todo[:completed] = completion_status
  end

  private

  def fetch_todos_from_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1;"
    result = query(sql, list_id)
    
    todos = []
    result.each do |tuple| 
      todos << {id: tuple["id"], name: tuple["name"], completed: tuple["completed"] }
    end
    todos.each do |todo|
      todo[:completed] == 't' ? todo[:completed] = true : todo[:completed] = false
    end
    todos
  end
end
