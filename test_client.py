#!/usr/bin/env python3
"""
QRSC_PC テストクライアント

このスクリプトは、QRSC_PCのHTTP/WebSocket APIをテストするためのものです。
スマホアプリの代わりとして使用できます。
"""

import requests
import json
import sys

class EYMTestClient:
    def __init__(self, host='localhost', port=8765):
        self.host = host
        self.port = port
        self.base_url = f'http://{host}:{port}'
        
    def test_health(self):
        """ヘルスチェック"""
        try:
            response = requests.get(f'{self.base_url}/health')
            print(f"Health Check: {response.status_code} - {response.text}")
            return response.status_code == 200
        except Exception as e:
            print(f"Health Check Failed: {e}")
            return False
    
    def get_shortcuts(self):
        """ショートカット一覧を取得"""
        try:
            response = requests.get(f'{self.base_url}/shortcuts')
            if response.status_code == 200:
                data = response.json()
                print("Shortcuts:")
                for shortcut in data.get('data', []):
                    print(f"  {shortcut['buttonId']}: {shortcut['name']} -> {shortcut['path']}")
                return data
            else:
                print(f"Get Shortcuts Failed: {response.status_code}")
                return None
        except Exception as e:
            print(f"Get Shortcuts Error: {e}")
            return None
    
    def launch_app(self, button_id):
        """アプリケーションを起動（HTTP POST）"""
        try:
            payload = {'button_id': button_id}
            response = requests.post(f'{self.base_url}/launch', json=payload)
            if response.status_code == 200:
                result = response.json()
                if result.get('success'):
                    print(f"Launch Success: Button {button_id} - {result.get('message')}")
                else:
                    print(f"Launch Failed: Button {button_id} - {result.get('message')}")
                return result
            else:
                print(f"Launch HTTP Error: {response.status_code}")
                return None
        except Exception as e:
            print(f"Launch Error: {e}")
            return None

def main():
    client = EYMTestClient()
    
    print("=== QRSC_PC Test Client ===")
    print(f"Target: {client.base_url}")
    print()
    
    # ヘルスチェック
    if not client.test_health():
        print("Server is not running or not accessible")
        return
    
    # ショートカット一覧を取得
    shortcuts = client.get_shortcuts()
    if not shortcuts:
        print("Failed to get shortcuts")
        return
    
    print()
    print("Available commands:")
    print("  l <button_id> - Launch app")
    print("  s - Show shortcuts")
    print("  q - Quit")
    print()
    
    # インタラクティブモード
    while True:
        try:
            command = input("Enter command: ").strip().lower()
            
            if command == 'q':
                break
            elif command == 's':
                client.get_shortcuts()
            elif command.startswith('l '):
                try:
                    button_id = int(command.split()[1])
                    client.launch_app(button_id)
                except (IndexError, ValueError):
                    print("Usage: l <button_id>")
            else:
                print("Unknown command")
        except KeyboardInterrupt:
            break
        except EOFError:
            break
    
    print("\nGoodbye!")

if __name__ == '__main__':
    main()
