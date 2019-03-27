require 'sqlite3'
require 'singleton'
require 'active_support/inflector'

class QuestionsDatabase < SQLite3::Database
    include Singleton

    def initialize
        super('aa_questions.db')
        self.type_translation = true
        self.results_as_hash = true
    end
end

class ModelBase
    def self.all
        data = QuestionsDatabase.instance.execute(<<-SQL)
            SELECT
            *
            FROM
                #{ActiveSupport::Inflector.tableize(self.to_s)}
        SQL
        data.map {|datum| self.new(datum)}
    end

    def self.find_by_id(id)
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT
                *
            FROM
                #{ActiveSupport::Inflector.tableize(self.to_s)}
            WHERE
                id = ?
        SQL
        raise "Not a valid" unless !data.empty?
        self.new(data.first)
    end

    def save
        if self.id.nil?
            keys = self.instance_variables.map { |iv| iv.to_s[1..-1]}
            values = self.instance_variables.map {|iv| self.instance_variable_get(iv)}
            QuestionsDatabase.instance.execute(<<-SQL, keys, values)
            INSERT INTO
                #{ActiveSupport::Inflector.tableize(self.to_s)} ?
            VALUES
                ?
            SQL
            self.id = QuestionsDatabase.instance.last_insert_row_id
            return self
        else
            correspondence = self.instance_variables.reject {|iv| iv == '@id'}
            correspondence.map! {|iv| "#{iv.to_s[1..-1]} = #{self.instance_variable_get(iv)}"}
            correspondence = correspondence.join(', ')
            QuestionsDatabase.instance.execute(<<-SQL, correspondence, self.id)
            UPDATE
                #{ActiveSupport::Inflector.tableize(self.to_s)}
            SET
                ?
            WHERE
                id = ?
            SQL
            return self
        end
    end
    
    def self.where(options)
        key = options.keys.first
        value = options.values.first
        p key
        data = QuestionsDatabase.instance.execute(<<-SQL, value)
            SELECT
                *
            FROM
                #{ActiveSupport::Inflector.tableize(self.to_s)}
            WHERE
                #{key} = ?
        SQL
        data.map { |datum| self.new(datum) }
    end

end
    

class User < ModelBase
    attr_accessor :id, :fname, :lname

    def self.find_by_name(fname, lname)
        data = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
            SELECT
                *
            FROM
                users
            WHERE
                fname = ? AND lname = ?
        SQL
        User.new(data.first)
    end
    
    def initialize(options)
        @id = options['id']
        @fname = options['fname']
        @lname = options['lname']
    end
    
    def authored_questions
        Question.find_by_author_id(self.id)
    end
    
    def authored_replies
        Reply.find_by_user_id(self.id)
    end
    
    def followed_questions
        QuestionFollow.followed_questions_for_user_id(self.id)
    end

    def liked_questions
        QuestionLike.liked_questions_for_user_id(self.id)
    end

    def average_karma
        data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
            SELECT
                CAST(COUNT(question_likes.user_id) / COUNT(DISTINCT(question_id)) AS FLOAT) AS karma
            FROM
                questions
            LEFT JOIN question_likes ON questions.id = question_likes.question_id
            WHERE
                questions.author_id = ?
        SQL
        data.first['karma'] || 0
    end

end

class Question < ModelBase
    attr_accessor :id, :title, :body, :author_id
    
    def self.find_by_author_id(author_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
        SELECT
        *
        FROM
        questions
        WHERE
        author_id = ?
        SQL
        data.map { |datum| Question.new(datum) }
    end

    def self.most_followed(n)
        QuestionFollow.most_followed_questions(n)
    end

    def self.most_liked(n)
        QuestionLike.most_liked_questions(n)
    end
    
    def initialize(options)
        @id = options['id']
        @title = options['title']
        @body = options['body']
        @author_id = options['author_id']
    end

    def author 
        User.find_by_id(self.author_id)
    end

    def replies
        Reply.find_by_question_id(self.id)
    end

    def followers
        QuestionFollow.followers_for_question_id(self.id)
    end

    def likers 
        QuestionLike.likers_for_question_id(self.id)
    end

    def num_likes
        QuestionLike.num_likes_for_question_id(self.id)
    end
end

class Reply < ModelBase
    attr_accessor :id, :question_id, :parent_reply, :user_id, :body

    def self.find_by_user_id(user_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
        SELECT
            *
        FROM
            replies
        WHERE
            user_id = ?
        SQL
        data.map { |datum| Reply.new(datum) }
    end

    def self.find_by_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
        SELECT
            *
        FROM
            replies
        WHERE
            question_id = ?
        SQL
        data.map { |datum| Reply.new(datum) }
    end

    def initialize(options)
        @id = options['id']
        @question_id = options['question_id']
        @parent_reply = options['parent_reply']
        @user_id = options['user_id']
        @body = options['body']
    end

    def author
        User.find_by_id(self.user_id)
    end

    def question 
        Question.find_by_id(self.question_id)
    end

    def get_parent_reply
        raise "no parent" if self.parent_reply.nil?
        Reply.find_by_id(self.parent_reply)
    end

    def child_replies
        Reply.find_by_question_id(self.question_id).select do |rep| 
            rep.parent_reply == self.id
        end
    end
end

class QuestionFollow < ModelBase
    attr_accessor :question_id, :follower_id

    def initialize(options)
        @question_id = options['question_id']
        @follower_id = options['follower_id']
    end

    def self.followers_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT
                users.*
            FROM
                users
            JOIN question_follows ON question_follows.follower_id = users.id
            WHERE
                question_id = ?
        SQL
        data.map { |datum| User.new(datum) }
    end

    def self.followed_questions_for_user_id(user_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
            SELECT
                questions.*
            FROM
                questions
            JOIN question_follows ON question_follows.question_id = questions.id
            WHERE
            follower_id = ?
            SQL
            data.map { |datum| Question.new(datum) }
        end
        
    def self.most_followed_questions(n)
        data = QuestionsDatabase.instance.execute(<<-SQL, n)
            SELECT
                questions.*
            FROM
                questions
            JOIN question_follows ON question_follows.question_id = questions.id
            GROUP BY
                questions.id
            ORDER BY
                COUNT(*) DESC
            LIMIT ?
        SQL
        data.map { |datum| Question.new(datum) }
    end

end

class QuestionLike < ModelBase
    attr_accessor

    def initialize(options)
        @user_id = options['user_id']
        @question_id = options['question_id']
    end 

    def self.likers_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT
                users.*
            FROM
                users
            JOIN question_likes ON users.id = question_likes.user_id
            WHERE
                question_likes.question_id = ?
        SQL
        data.map { |datum| User.new(datum) }
    end

    def self.num_likes_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT
                COUNT(*) AS count
            FROM
                users
            JOIN question_likes ON users.id = question_likes.user_id
            WHERE
                question_likes.question_id = ?
        SQL
        return data.first['count']
    end

    def self.liked_questions_for_user_id(user_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
            SELECT
                questions.*
            FROM
                questions
            JOIN question_likes ON questions.id = question_likes.question_id
            WHERE
                question_likes.user_id = ?
        SQL
        data.map { |datum| Questions.new(datum) }
    end

    def self.most_liked_questions(n)
        data = QuestionsDatabase.instance.execute(<<-SQL, n)
            SELECT
                questions.*
            FROM
                questions
            JOIN question_likes ON question_likes.question_id = questions.id
            GROUP BY
                questions.id
            ORDER BY
                COUNT(*) DESC
            LIMIT ?
        SQL
        data.map { |datum| Question.new(datum) }
    end
end