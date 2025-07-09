import curses
import os
import subprocess
import sys
import time
import shutil
import threading

# Cache untuk ukuran direktori
directory_size_cache = {}
cache_lock = threading.Lock() # Lock untuk akses aman ke cache

def format_bytes(size_bytes):
    """
    Mengubah ukuran bytes menjadi format yang lebih mudah dibaca (KB, MB, GB, dll.).

    Args:
        size_bytes (int): Ukuran dalam bytes.

    Returns:
        str: Ukuran yang diformat.
    """
    if size_bytes == 0:
        return "0 Bytes"
    size_name = ("Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = 0
    while size_bytes >= 1024 and i < len(size_name) - 1:
        size_bytes /= 1024
        i += 1
    s = round(size_bytes, 2)
    return f"{s} {size_name[i]}"

def get_directory_size_cached(path):
    """
    Mendapatkan ukuran direktori menggunakan 'du -sh', dengan mempertimbangkan cache.

    Args:
        path (str): Jalur direktori.

    Returns:
        str: Ukuran direktori dalam format human-readable atau pesan error jika gagal.
    """
    with cache_lock:
        if path in directory_size_cache:
            return directory_size_cache[path]

    if not os.path.isdir(path):
        return "Error: Not a directory"

    try:
        result = subprocess.run(['du', '-sh', path], capture_output=True, text=True, check=True)
        size_str = result.stdout.split()[0]
        with cache_lock:
            directory_size_cache[path] = size_str
        return size_str
    except FileNotFoundError:
        return "Error: 'du' not found"
    except subprocess.CalledProcessError as e:
        return f"Error: {e}"
    except Exception as e:
        return f"Error: {e}"

def get_file_size(path):
    """
    Mendapatkan ukuran file dalam format human-readable.

    Args:
        path (str): Jalur file.

    Returns:
        str: Ukuran file dalam format human-readable atau pesan error jika gagal.
    """
    if not os.path.isfile(path):
        return "Error: Not a file"
    try:
        size_bytes = os.path.getsize(path)
        return format_bytes(size_bytes)
    except OSError as e:
        return f"Error: {e}"
    except Exception as e:
        return f"Error: {e}"

def get_directory_contents(path):
    """
    Mendapatkan isi direktori (file dan subdirektori) beserta ukurannya.

    Args:
        path (str): Jalur direktori.

    Returns:
        list: Daftar tuple (nama_item, ukuran_str, is_directory)
              atau None jika gagal.
    """
    contents = []
    if not os.path.isdir(path):
        return [("Error: Not a directory", "", False)]

    try:
        for item in os.listdir(path):
            item_path = os.path.join(path, item)
            is_dir = os.path.isdir(item_path)
            if is_dir:
                size_str = get_directory_size_cached(item_path)
            else:
                size_str = get_file_size(item_path)
            contents.append((item, size_str, is_dir))
        return contents
    except OSError as e:
        return [(f"Error listing: {e}", "", False)]
    except Exception as e:
        return [(f"Error: {e}", "", False)]

def main_curses(stdscr):
    """
    Fungsi utama untuk menjalankan aplikasi curses.
    """
    curses.curs_set(0)  # Sembunyikan kursor
    stdscr.nodelay(1)   # Buat input non-blocking
    stdscr.timeout(100) # Timeout untuk input (100ms)

    current_path = os.getcwd()
    selected_index = 0
    scroll_offset = 0
    contents = []
    is_loading = False
    loading_thread = None
    status_message = "Ready."

    def load_contents(path):
        nonlocal contents, is_loading, status_message
        is_loading = True
        status_message = "Loading..."
        new_contents = get_directory_contents(path)
        contents = new_contents
        is_loading = False
        status_message = "Ready."

    # Mulai pemuatan awal
    loading_thread = threading.Thread(target=load_contents, args=(current_path,))
    loading_thread.start()

    while True:
        max_y, max_x = stdscr.getmaxyx()

        # Header
        stdscr.addstr(0, 0, f"Current Directory: {current_path}", curses.A_BOLD)
        stdscr.addstr(1, 0, "-" * (max_x - 1))

        # Tampilkan isi direktori
        num_items = len(contents)
        display_items = max_y - 3 # Kurangi header, separator, dan footer

        # Sesuaikan scroll
        if selected_index < scroll_offset:
            scroll_offset = selected_index
        if selected_index >= scroll_offset + display_items:
            scroll_offset = selected_index - display_items + 1
        if scroll_offset < 0:
            scroll_offset = 0

        # Perbarui hanya baris item yang berubah
        for i in range(display_items):
            item_index = scroll_offset + i
            y_pos = i + 2 # Mulai dari baris 2

            if item_index < num_items:
                item_name, item_size, is_dir = contents[item_index]
                attr = curses.A_REVERSE if item_index == selected_index else 0

                # Format tampilan
                prefix = "[DIR]" if is_dir else "[FILE]"
                display_text = f"{prefix} {item_name} ({item_size})"

                # Potong teks jika terlalu panjang
                if len(display_text) > max_x - 1:
                    display_text = display_text[:max_x - 4] + "..."

                stdscr.addstr(y_pos, 0, display_text, attr)
            else:
                # Kosongkan baris yang tersisa
                stdscr.addstr(y_pos, 0, " " * (max_x - 1))

        # Footer
        stdscr.addstr(max_y - 2, 0, "-" * (max_x - 1))
        # Perbarui baris status
        stdscr.addstr(max_y - 1, 0, " " * (max_x - 1)) # Bersihkan baris status sebelumnya
        if is_loading:
            stdscr.addstr(max_y - 1, 0, status_message, curses.A_BLINK)
        else:
            stdscr.addstr(max_y - 1, 0, "Up/Down: Navigate | Enter: Open | ..: Parent | Q: Quit")

        stdscr.refresh()

        # Handle input
        key = stdscr.getch()

        if key == curses.KEY_UP:
            selected_index = max(0, selected_index - 1)
        elif key == curses.KEY_DOWN:
            selected_index = min(num_items - 1, selected_index + 1)
        elif key == curses.KEY_ENTER or key == ord('\n'):
            if not is_loading and selected_index < num_items:
                item_name, item_size, is_dir = contents[selected_index]
                item_path = os.path.join(current_path, item_name)

                if is_dir:
                    if os.path.isdir(item_path):
                        current_path = item_path
                        selected_index = 0
                        scroll_offset = 0
                        # Mulai pemuatan baru di latar belakang
                        loading_thread = threading.Thread(target=load_contents, args=(current_path,))
                        loading_thread.start()
                    else:
                        # Tampilkan pesan error jika bukan direktori
                        stdscr.addstr(max_y - 3, 0, f"Error: '{item_name}' is not a directory.", curses.A_RED)
                        stdscr.refresh()
                        time.sleep(1)
                else:
                    # Tampilkan ukuran file di footer
                    stdscr.addstr(max_y - 3, 0, f"Size of '{item_name}': {item_size}", curses.A_CYAN)
                    stdscr.refresh()
                    time.sleep(1)
        elif key == ord('q'):
            break
        elif key == ord('.'):
            if not is_loading:
                parent_path = os.path.dirname(current_path)
                if parent_path != current_path: # Hindari naik ke root dari root
                    current_path = parent_path
                    selected_index = 0
                    scroll_offset = 0
                    # Mulai pemuatan baru di latar belakang
                    loading_thread = threading.Thread(target=load_contents, args=(current_path,))
                    loading_thread.start()

if __name__ == "__main__":
    try:
        curses.wrapper(main_curses)
    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)
