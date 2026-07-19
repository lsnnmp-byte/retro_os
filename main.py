import time
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.core.window import Window
from kivy.clock import Clock
from kivy.utils import platform

# Set a dark background palette simulation for the app canvas
Window.clearcolor = (0.07, 0.07, 0.08, 1) 

class ADBCompanionApp(App):
    def build(self):
        # Main layout wrapper with clean spacing
        self.layout = BoxLayout(orientation='vertical', padding=40, spacing=30)
        
        # Upper Header Section
        self.header = Label(
            text="PYTHON ADB COMPANION",
            font_size='14sp',
            bold=True,
            color=(0.20, 0.60, 0.86, 1), # Light Blue theme color
            size_hint_y=None,
            height=50
        )
        self.layout.add_widget(self.header)
        
        # Connection Status Box Container
        self.status_box = BoxLayout(orientation='vertical', padding=20, spacing=10)
        
        self.status_title = Label(text="Connection Status", font_size='14sp', color=(0.5, 0.5, 0.5, 1), halign='left')
        self.status_text = Label(text="STANDBY MODE", font_size='28sp', bold=True, color=(0.91, 0.30, 0.24, 1)) # Light red
        
        self.status_box.add_widget(self.status_title)
        self.status_box.add_widget(self.status_text)
        self.layout.add_widget(self.status_box)
        
        # Details Box Container
        self.details_box = BoxLayout(orientation='vertical', padding=10)
        self.details_title = Label(text="Host Machine Signature:", font_size='12sp', color=(0.5, 0.5, 0.5, 1))
        self.details_text = Label(text="Searching for Active ADB Host...", font_size='15sp', color=(1, 1, 1, 1))
        
        self.details_box.add_widget(self.details_title)
        self.details_box.add_widget(self.details_text)
        self.layout.add_widget(self.details_box)
        
        # Red Termination Action Button
        self.disconnect_btn = Button(
            text="FORCE DISCONNECT ENGINE",
            font_size='16sp',
            bold=True,
            background_color=(0.91, 0.30, 0.24, 1),
            background_normal='',
            size_hint_y=None,
            height=60
        )
        self.disconnect_btn.bind(on_press=self.terminate_app)
        self.layout.add_widget(self.disconnect_btn)
        
        # Check system link connections every 2 seconds
        Clock.schedule_interval(self.update_connection_status, 2.0)
        
        return self.layout

    def update_connection_status(self, dt):
        # Native Android API check if running on a real phone layer
        if platform == 'android':
            from jnius import autoclass
            Context = autoclass('android.content.Context')
            IntentFilter = autoclass('android.content.IntentFilter')
            PythonActivity = autoclass('org.kivy.android.PythonActivity')
            
            current_activity = PythonActivity.mActivity
            filter = IntentFilter("android.hardware.usb.action.USB_STATE")
            usb_intent = current_activity.registerReceiver(None, filter)
            
            is_usb_on = usb_intent.getBooleanExtra("connected", False) if usb_intent else False
            
            if is_usb_on:
                self.status_text.text = "LINK ACTIVE"
                self.status_text.color = (0.18, 0.80, 0.44, 1) # Emerald Green
                self.details_text.text = "Connected to Cloud Codespace Workstation"
            else:
                self.status_text.text = "STANDBY MODE"
                self.status_text.color = (0.91, 0.30, 0.24, 1)
                self.details_text.text = "Searching for Active ADB Host..."
        else:
            # Fallback text if testing the UI locally inside your Codespace preview env
            self.status_text.text = "DESKTOP PREVIEW"
            self.status_text.color = (0.20, 0.60, 0.86, 1)
            self.details_text.text = "Running outside native Android hardware environment."

    def terminate_app(self, instance):
        App.get_running_app().stop()

if __name__ == '__main__':
    ADBCompanionApp().run()