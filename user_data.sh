#!/bin/bash

# Update the system
yum update -y

# Install required packages
yum install -y python3 sqlite

# Install pip
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py
rm get-pip.py

# Install application dependencies
pip3 install flask gunicorn

# Create application directory
mkdir -p /opt/studentapp
cd /opt/studentapp

# Create database directory with proper permissions
mkdir -p /var/lib/studentapp
chmod 755 /var/lib/studentapp
touch /var/lib/studentapp/students.db
chmod 644 /var/lib/studentapp/students.db

# Create symbolic link to database
ln -s /var/lib/studentapp/students.db /opt/studentapp/students.db

# Download application files
cat > app.py << 'EOF'
from flask import Flask, render_template, request, redirect, url_for, flash
import sqlite3
import os
from datetime import datetime

app = Flask(__name__)
app.secret_key = os.urandom(24)

# SQLite database configuration
DB_PATH = '/opt/studentapp/students.db'

def get_db_connection():
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error as e:
        flash(f"Database connection error: {e}", 'danger')
        return None

def init_db():
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute('''
                CREATE TABLE IF NOT EXISTS students (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    student_id TEXT UNIQUE NOT NULL,
                    first_name TEXT NOT NULL,
                    last_name TEXT NOT NULL,
                    email TEXT UNIQUE NOT NULL,
                    phone TEXT,
                    program TEXT,
                    enrollment_date TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            conn.commit()
        except sqlite3.Error as e:
            flash(f"Database initialization error: {e}", 'danger')
        finally:
            conn.close()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/students', methods=['GET', 'POST'])
def students():
    if request.method == 'POST':
        # Handle form submission
        student_id = request.form['student_id']
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        email = request.form['email']
        phone = request.form.get('phone', '')
        program = request.form.get('program', '')
        enrollment_date = request.form.get('enrollment_date', '')

        conn = get_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute('''
                    INSERT INTO students 
                    (student_id, first_name, last_name, email, phone, program, enrollment_date)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (student_id, first_name, last_name, email, phone, program, enrollment_date))
                conn.commit()
                flash('Student added successfully!', 'success')
            except sqlite3.Error as e:
                conn.rollback()
                flash(f'Error adding student: {e}', 'danger')
            finally:
                conn.close()
            return redirect(url_for('students'))

    # GET request - show all students
    conn = get_db_connection()
    students = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute('SELECT * FROM students ORDER BY created_at DESC')
            students = cur.fetchall()
        except sqlite3.Error as e:
            flash(f'Error fetching students: {e}', 'danger')
        finally:
            conn.close()
    
    return render_template('students.html', students=students)

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000)
EOF

mkdir -p templates
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Student Data Collection</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-5">
        <h1>Welcome to Student Data Collection</h1>
        <div class="mt-4">
            <a href="/students" class="btn btn-primary">View Students</a>
            <a href="/students" class="btn btn-success">Add New Student</a>
        </div>
    </div>
</body>
</html>
EOF

cat > templates/students.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Student Data</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-5">
        <h1>Student Data</h1>
        
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert alert-{{ category }}">{{ message }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}

        <div class="row mt-4">
            <div class="col-md-6">
                <h2>Add New Student</h2>
                <form method="POST">
                    <div class="mb-3">
                        <label class="form-label">Student ID</label>
                        <input type="text" class="form-control" name="student_id" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">First Name</label>
                        <input type="text" class="form-control" name="first_name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Last Name</label>
                        <input type="text" class="form-control" name="last_name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Email</label>
                        <input type="email" class="form-control" name="email" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Phone</label>
                        <input type="text" class="form-control" name="phone">
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Program</label>
                        <input type="text" class="form-control" name="program">
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Enrollment Date</label>
                        <input type="date" class="form-control" name="enrollment_date">
                    </div>
                    <button type="submit" class="btn btn-primary">Submit</button>
                </form>
            </div>
            <div class="col-md-6">
                <h2>Student List</h2>
                {% if students %}
                    <table class="table">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>Email</th>
                                <th>Program</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for student in students %}
                                <tr>
                                    <td>{{ student[1] }}</td>
                                    <td>{{ student[2] }} {{ student[3] }}</td>
                                    <td>{{ student[4] }}</td>
                                    <td>{{ student[6] }}</td>
                                </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                {% else %}
                    <p>No students found.</p>
                {% endif %}
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Initialize the database
python3 -c "from app import init_db; init_db()"

# Start the application
gunicorn -b 0.0.0.0:5000 app:app &

# Enable auto-start on boot
cat > /etc/systemd/system/studentapp.service << 'EOF'
[Unit]
Description=Student Data Collection App
After=network.target

[Service]
User=root
WorkingDirectory=/opt/studentapp
ExecStart=/usr/local/bin/gunicorn -b 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable studentapp
systemctl start studentapp