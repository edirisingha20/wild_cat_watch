# wild_cat_watch

🐘 Wildlife Alert – Location-Based Community Wildlife Notification System

A mobile-based, community-driven wildlife alert system designed to improve public safety and reduce human–wildlife conflict by enabling real-time reporting and location-based notifications of special wildlife sightings.

📌 Project Overview

Human–wildlife interactions are increasing in rural and semi-rural regions, leading to safety risks for both people and animals. Sightings of animals such as elephants, leopards, and other potentially dangerous wildlife are often reported late or informally, making timely response difficult.

This project provides a real-time, location-aware mobile solution where users can report wildlife sightings and instantly alert nearby community members.

🎯 Objectives

Enable real-time reporting of wildlife sightings

Automatically capture GPS-based location data

Notify nearby users only, based on geographic radius

Improve community awareness and safety

Create a foundation for future AI-based animal recognition

🚀 Key Features

📸 Photo-based wildlife sighting reports

📍 Automatic GPS location detection

🔔 Location-based push notifications

🗺 Map view of recent wildlife sightings

🧑‍🤝‍🧑 Community-driven reporting system

🗄 Historical data storage for analysis

🏗 System Architecture

The system consists of four main components:

Mobile Application (Flutter)

User-friendly interface

Camera and GPS integration

Push notification handling

Backend Server (Django + DRF)

RESTful API services

Business logic and validation

Location-based filtering

Database (MySQL)

Stores users, sightings, locations, and timestamps

Maintains historical wildlife sighting data

Notification Service (Firebase Cloud Messaging)

Sends real-time alerts

Targets users within a defined radius

🧭 System Workflow

A user spots a special animal

The user captures a photo using the mobile app

GPS location and timestamp are automatically recorded

The report is sent to the backend server

Data is stored in the database

Nearby users are identified

Push notifications are sent in real time

🛠 Technology Stack
Frontend (Mobile App)

Flutter

Google Maps (optional visualization)

Mobile GPS services

Backend

Django

Django REST Framework (DRF)

Database

MySQL

Notifications

Firebase Cloud Messaging (FCM)

📱 Main Screens (Planned)

Home / Recent Alerts

Map View (Sightings with markers)

Report Sighting

Alert Notification View

User Profile

🧪 Testing Strategy

Backend API testing

Location accuracy testing

Notification delivery testing

Integration testing (Flutter ↔ Django)

📚 Research & Social Impact

This system contributes to:

Reducing human–wildlife conflict

Enhancing community safety

Supporting wildlife conservation efforts

Providing data for environmental research

Enabling data-driven decision making

🔮 Future Enhancements

AI-based automatic animal identification

User trust and credibility scoring

Duplicate and false report detection

Admin/authority verification panel

Analytics dashboard for wildlife departments

Emergency service integration

👨‍💻 Development Status

🚧 Currently under development
Initial focus: Core reporting, GPS capture, and alert notification system.

🤝 Contributors

Dewmal – Project Owner

Kavinda Supun – Developer

📄 License

This project is developed for academic and research purposes.
License details will be added in future releases.

📬 Contact

For questions, suggestions, or collaboration:
📧 Contact details can be added here

Starting developments by kavinda