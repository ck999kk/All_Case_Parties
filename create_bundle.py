import os
import re
from bs4 import BeautifulSoup
import urllib.parse

def create_printable_summary():
    """
    Combines the main index.html and all related message HTML files into a single,
    self-contained, printable HTML document.
    """
    try:
        # --- 1. Read the main index.html file ---
        with open('index.html', 'r', encoding='utf-8') as f:
            index_content = f.read()

        soup = BeautifulSoup(index_content, 'html.parser')

        # --- 2. Extract the main table and styles ---
        main_table = soup.find('table')
        styles = soup.find('style')

        if not main_table:
            print("Error: Could not find the main table in index.html.")
            return

        # --- 3. Create the structure for the new printable HTML ---
        printable_html = f"""
        <html>
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <title>Printable Email Summary</title>
            <style>
                {styles.string if styles else ''}
                body {{ font-family: sans-serif; }}
                .page-break {{ page-break-after: always; }}
                .email-container {{ border: 1px solid #ccc; padding: 20px; margin-bottom: 20px; }}
                h2, h3 {{ color: #333; }}
            </style>
        </head>
        <body>
            <h1>Email Message Summary</h1>
            <h2>Case Parties: All_Case_Parties (10/05/2025)</h2>
        """

        # --- 4. Process each message linked in the index.html file ---
        message_links = main_table.find_all('a', href=True)
        
        for i, link in enumerate(message_links):
            encoded_path = link['href']
            # Decode the URL-encoded path
            decoded_path = urllib.parse.unquote(encoded_path)
            
            # Construct the full path relative to the script's location
            full_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), decoded_path)

            if os.path.exists(full_path):
                with open(full_path, 'r', encoding='utf-8', errors='ignore') as msg_file:
                    msg_content = msg_file.read()
                    msg_soup = BeautifulSoup(msg_content, 'html.parser')

                    # Extract subject from the message
                    subject_tag = msg_soup.find('title')
                    subject = subject_tag.string if subject_tag else 'No Subject'

                    # Add a container for each email
                    printable_html += f"""
                    <div class="email-container">
                        <h3>{i + 1}. {subject}</h3>
                        <hr>
                        <div class="email-body">
                            {msg_soup.body.prettify() if msg_soup.body else ''}
                        </div>
                    </div>
                    <div class="page-break"></div>
                    """
            else:
                print(f"Warning: File not found - {full_path} (decoded from {encoded_path})")

        printable_html += """
        </body>
        </html>
        """

        # --- 5. Write the combined content to a new file ---
        with open('printable_summary.html', 'w', encoding='utf-8') as f:
            f.write(printable_html)

        print("Successfully created printable_summary.html")
        print("You can now open this file in your browser and print to PDF.")

    except FileNotFoundError:
        print("Error: 'index.html' not found. Make sure you are in the correct directory.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == '__main__':
    create_printable_summary()