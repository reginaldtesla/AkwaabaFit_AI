# AkwaabaFitAIProject

## Overview

AkwaabaFitAIProject is a culturally-adapted AI-powered fitness application designed specifically for Ghanaians. Built with the Ghanaian context in mind, this app combines traditional fitness principles with modern AI technology to provide personalized workout recommendations, nutritional guidance, and health tracking tailored to the Ghanaian lifestyle and dietary preferences.

The app addresses the growing need for accessible fitness solutions in Ghana by incorporating local foods, cultural fitness practices, and AI-driven personalization. Whether you're a busy professional in Accra, a student in Kumasi, or someone looking to maintain a healthy lifestyle anywhere in Ghana, AkwaabaFitAI provides "welcome" (akwaaba) access to fitness and wellness.

The project consists of a Laravel-based backend API and a Flutter mobile application, designed to deliver a seamless, culturally-relevant fitness experience across iOS and Android devices.

## Project Structure

```
AkwaabaFitAIProject/
├── Backend/          # Laravel API backend
├── Mobile/           # Flutter mobile application
└── README.md         # This file
```

## Features

- **AI-Powered Workouts**: Personalized workout recommendations based on user goals and fitness level
- **Progress Tracking**: Monitor fitness progress over time
- **User Authentication**: Secure user accounts with Laravel Sanctum
- **Cross-Platform Mobile App**: Flutter app that works on iOS and Android
- **RESTful API**: Well-structured backend API for data management

## How It Works

### 1. User Onboarding & Profiling

- Users create accounts and complete a comprehensive health profile
- Input includes fitness goals, current fitness level, dietary preferences, and lifestyle factors
- Cultural considerations: Ghanaian dietary patterns, local food preferences, and traditional activities

### 2. AI-Powered Recommendations

- Machine learning algorithms analyze user data to generate personalized workout plans
- Recommendations consider Ghanaian climate, available local gym facilities, and cultural fitness practices
- Adaptive AI that learns from user progress and adjusts recommendations over time

### 3. Workout Execution & Tracking

- Step-by-step workout guidance with video demonstrations
- Real-time progress tracking during exercises
- Integration with wearable devices for automatic data collection

### 4. Nutritional Guidance

- Meal plans featuring Ghanaian cuisine (banku, jollof rice, waakye, etc.)
- Nutritional information adapted to local food availability and cultural preferences
- Calorie tracking with Ghanaian portion sizes and meal patterns

### 5. Progress Monitoring & Analytics

- Visual progress charts and milestone celebrations
- Weekly/monthly reports on fitness improvements
- Community features to connect with other Ghanaian fitness enthusiasts

### 6. Cultural Integration

- Incorporation of traditional Ghanaian games and activities (ampe, oware, etc.) as fitness options
- Local language support and culturally relevant motivational content
- Community challenges and group fitness events

The app leverages AI to make fitness accessible and enjoyable for Ghanaians, bridging traditional wellness practices with modern technology.

### Backend

- **Laravel 12**: PHP framework for robust API development
- **Laravel Sanctum**: API authentication
- **MySQL/PostgreSQL**: Database (configurable)
- **Pest**: PHP testing framework

### Mobile

- **Flutter**: Cross-platform mobile development
- **Dart**: Programming language

## Prerequisites

### Backend Requirements

- PHP 8.2 or higher
- Composer
- Node.js & npm (for asset compilation)
- MySQL/PostgreSQL database

### Mobile Requirements

- Flutter SDK
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

## Installation & Setup

### Backend Setup

1. Navigate to the Backend directory:

   ```bash
   cd Backend
   ```

2. Install PHP dependencies:

   ```bash
   composer install
   ```

3. Install Node.js dependencies:

   ```bash
   npm install
   ```

4. Copy environment file and configure:

   ```bash
   cp .env.example .env
   ```

5. Generate application key:

   ```bash
   php artisan key:generate
   ```

6. Configure your database in `.env` file

7. Run database migrations:

   ```bash
   php artisan migrate
   ```

8. Start the development server:
   ```bash
   php artisan serve
   ```

### Mobile Setup

1. Navigate to the Mobile directory:

   ```bash
   cd Mobile
   ```

2. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## API Documentation

The backend provides RESTful APIs for:

- User authentication and management
- Workout data management
- Progress tracking
- AI recommendations

API endpoints are defined in `Backend/routes/api.php`

## Testing

### Backend Testing

```bash
cd Backend
php artisan test
```

### Mobile Testing

```bash
cd Mobile
flutter test
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Project Team

This is a final year group project. Team members:

- Darko Kwaku Agyemang
- Bernard
- Klenam

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Laravel Framework
- Flutter Framework
- All contributors and supporters

## Contact

For questions or support, please contact the project maintainers.
