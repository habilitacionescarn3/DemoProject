import os
import time
from flask import Flask, render_template_string
import psycopg2

app = Flask(__name__)

# Récupération des variables d'environnement (Sécurité : pas de mdp en clair)
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_NAME = os.environ.get('DB_NAME', 'devopsdb')
DB_USER = os.environ.get('DB_USER', 'postgres')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'secret')

def get_db_connection():
    retries = 5
    while True:
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD
            )
            return conn
        except psycopg2.OperationalError as e:
            if retries == 0:
                raise e
            retries -= 1
            time.sleep(2)

# Initialisation de la base de données
conn = get_db_connection()
cursor = conn.cursor()
cursor.execute('''
    CREATE TABLE IF NOT EXISTS hits (
        id SERIAL PRIMARY KEY,
        count INT NOT NULL
    );
''')
cursor.execute('SELECT COUNT(*) FROM hits;')
if cursor.fetchone()[0] == 0:
    cursor.execute('INSERT INTO hits (count) VALUES (0);')
conn.commit()
cursor.close()
conn.close()

@app.route('/')
def hello():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Incrémenter le compteur
    cursor.execute('UPDATE hits SET count = count + 1 WHERE id = 1;')
    conn.commit()
    
    # Récupérer la valeur
    cursor.execute('SELECT count FROM hits WHERE id = 1;')
    hits = cursor.fetchone()[0]
    
    cursor.close()
    conn.close()
    
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Bootcamp DevOps</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; margin-top: 10%; background-color: #f4f4f9; }
            .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); display: inline-block; }
            h1 { color: #0078d4; }
            .counter { font-size: 2em; color: #2ecc71; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Félicitations ! L'application est en ligne.</h1>
            <p>Cette page a été vue <span class="counter">{{ hits }}</span> fois.</p>
            <small>Propulsé par Docker & Azure</small>
        </div>
    </body>
    </html>
    """
    return render_template_string(html, hits=hits)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)