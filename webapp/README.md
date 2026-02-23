# Mineral Traceability Web Dashboard

Modern HTML web dashboard for the Mineral Traceability System, providing real-time monitoring and analytics for mineral verification operations.

## Features

- **Real-time Metrics**: Live tracking of gold, chalcopyrite, and hematite detections
- **Trend Analysis**: 7-day visualization of mineral detection trends
- **Site Performance**: Monitor accuracy and verification rates across mining sites
- **Model Analytics**: Track ML model performance with precision, recall, and F1-score
- **Activity Feed**: Real-time feed of recent fingerprint verifications
- **Heatmap Visualization**: Site-level activity intensity mapping
- **Real-time Notifications**: Live alerts for new user registrations and scans
- **Audit Trail**: Complete system activity history tracking
- **Responsive Design**: Works on desktop, tablet, and mobile devices

## Real-Time Notifications 🔔

The system now includes a comprehensive notification system that alerts administrators in real-time:

### Notification Features:
- **New User Registration**: Instant alerts when new users create accounts
- **New Scan Alerts**: Notifications when fingerprint scans are captured
- **Desktop Notifications**: Browser push notifications (requires permission)
- **Sound Alerts**: Subtle audio notification for new events
- **Notification Badge**: Red badge shows unread notification count
- **Dropdown Menu**: Click the bell icon to view all notifications
- **Auto-refresh**: Checks for new events every 30 seconds
- **Persistent Storage**: Notifications saved in browser localStorage
- **Click Actions**: Click notifications to navigate to relevant pages
- **Mark as Read**: Automatically marks notifications as read when viewed
- **Clear All**: Option to clear all notifications at once

### Notification Types:
1. **User Registration** (Purple icon)
   - Shows user name, role, and email
   - Clicking navigates to Users page
   
2. **New Scan** (Blue icon)
   - Shows mineral type, confidence, site, and user
   - Clicking navigates to Scans page

### How It Works:
- System polls the API every 30 seconds for new data
- Compares timestamps with last check time
- Generates notifications for events after last check
- Shows browser notification for most recent event
- Stores up to 50 most recent notifications
- Displays last 10 notifications in dropdown

## Pages

### 1. Dashboard ([index.html](index.html))
- Real-time metrics overview
- 7-day trend charts
- Site performance cards
- Model accuracy gauge
- Activity feed
- Location heatmap

### 2. Verifications ([verifications.html](verifications.html))
- Complete verification records table
- Filter by site and status
- Search functionality
- Pagination support
- Status badges (Verified, Pending, Not Verified)
- Confidence levels display

### 3. Analytics ([analytics.html](analytics.html))
- Overall model performance metrics
- Confusion matrix visualization
- Per-class performance radar chart
- Confidence distribution histogram
- Modality usage breakdown
- Detailed metrics table by mineral

### 4. Scans ([scans.html](scans.html))
- Complete fingerprint scan records
- Filter by site and mineral
- Modality indicators (image, audio, chemical)
- GPS coordinates with map links
- Pagination and search
- User attribution

### 5. Sites ([sites.html](sites.html))
- Site-specific performance cards
- Mineral distribution by site
- Recent activity (24h)
- Verification rates per site
- Site comparison charts
- Stacked mineral distribution chart

### 6. Users ([users.html](users.html))
- User management table
- Role-based filtering (Admin, Inspector, Regulator)
- Scan count per user
- User activity status
- Search functionality

### 7. Reports ([reports.html](reports.html))
- Summary report generation
- Performance report templates
- Verification reports
- User activity reports
- Data export (JSON, CSV)
- Current period summary dashboard

### 8. Audit Trail ([audit-trail.html](audit-trail.html))
- Complete system activity history
- Timeline view of all events
- Filter by action type (scan, verification, user, system)
- Filter by user and time period
- Event details with metadata
- Pagination support
- Real-time activity tracking

## Tech Stack

- **HTML5**: Semantic markup
- **CSS3**: Modern styling with CSS Grid and Flexbox
- **Vanilla JavaScript**: No frameworks, pure JS
- **Chart.js 4.4.0**: Data visualization
- **Font Awesome 6.4.0**: Icons
- **Google Fonts (Inter)**: Typography

## Project Structure

```
webapp/
├── index.html          # Main dashboard page
├── verifications.html  # Verification records
├── analytics.html      # Model analytics & metrics
├── scans.html          # Fingerprint scans table
├── sites.html          # Site performance
├── users.html          # User management
├── reports.html        # Reports & exports
├── audit-trail.html    # System activity history
├── css/
│   └── style.css      # Complete styling
├── js/
│   ├── config.js      # API configuration
│   ├── api.js         # API service layer
│   ├── notifications.js # Real-time notification system
│   ├── dashboard.js   # Dashboard logic
│   ├── verifications.js
│   ├── analytics.js
│   ├── scans.js
│   ├── sites.js
│   ├── users.js
│   ├── reports.js
│   └── audit-trail.js # Audit trail logic
└── README.md          # This file
```

## Installation

1. **No build step required** - Pure HTML/CSS/JS
2. **No dependencies to install** - Uses CDN for libraries

## Running the Web App

### Option 1: Using Python HTTP Server (Recommended)

Open a terminal in the `webapp/` directory and run:

```bash
# Python 3.x
python -m http.server 8080

# Then open: http://localhost:8080
```

### Option 2: Using VS Code Live Server

1. Install the "Live Server" extension in VS Code
2. Right-click on `index.html`
3. Select "Open with Live Server"

### Option 3: Direct File Access

Simply open `index.html` in your browser. Note: Some features may require a local server due to CORS restrictions.

## API Configuration

The web app connects to the FastAPI backend at `http://127.0.0.1:8000`.

To change the API URL, edit `js/config.js`:

```javascript
const API_BASE_URL = 'http://127.0.0.1:8000';
```

## Data Sources

The dashboard connects directly to the FastAPI backend:
- `GET /fingerprints` - Retrieves all fingerprint records from database
- `GET /stats` - Gets real-time statistics (scans, verifications, mineral counts)
- `GET /metrics` - Fetches ML model performance metrics

**The API must be running for the dashboard to display data.**

## Starting the Backend API

The web app requires the FastAPI backend to be running:

```bash
cd c:\Users\HP\Mission-Capstone
python API/api.py
```

This starts the API on `http://127.0.0.1:8000`.

## Dashboard Sections

### 1. Top Bar
- Search functionality
- Total scans count
- Verified fingerprints count
- Overall accuracy rate
- Notifications

### 2. Metrics Overview (Left Column)
- Gold detection count with trend indicator
- Chalcopyrite detection count with trend indicator
- Hematite detection count with trend indicator
- Recent activity feed with timestamps

### 3. Analytics (Middle Column)
- 7-day trend chart showing detections over time
- Time filter buttons (7D, 30D, 90D, All)
- Site performance cards with:
  - Total scans per site
  - Verified counts
  - Accuracy percentages
  - Progress bars

### 4. Performance (Right Column)
- Model accuracy gauge (doughnut chart)
- Precision, Recall, F1-Score metrics
- Location heatmap showing activity intensity
- Quick action buttons:
  - New Scan
  - Generate Report
  - Export Data

## Auto-Refresh

The dashboard automatically refreshes data every **30 seconds**.

To change this interval, edit `js/config.js`:

```javascript
const REFRESH_INTERVAL = 30000; // milliseconds
```

## Browser Compatibility

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

## Customization

### Colors

Edit CSS variables in `css/style.css`:

```css
:root {
    --primary-blue: #3B82F6;
    --gold: #F59E0B;
    --copper: #EA580C;
    --iron: #DC2626;
    /* ... more variables */
}
```

### Chart Themes

Modify Chart.js defaults in `js/config.js`:

```javascript
Chart.defaults.font.family = "'Inter', sans-serif";
Chart.defaults.font.size = 12;
Chart.defaults.color = '#6B7280';
```

## Responsive Breakpoints

- **Desktop**: > 1400px (3-column layout)
- **Tablet**: 1024px - 1400px (2-column layout)
- **Mobile**: < 1024px (1-column layout)

## Troubleshooting

### Dashboard shows no data
- Ensure the API is running (`python API/api.py`)
- Check that log files exist in `logs/` directory
- Verify CORS is enabled in API

### Charts not rendering
- Check browser console for errors
- Ensure Chart.js CDN is accessible
- Verify JavaScript is not blocked

### Loading overlay stuck
- Check network connection to API
- Open browser DevTools (F12) → Console for errors
- Verify API endpoint in `js/config.js`

## Future Enhancements

- [ ] Additional pages: Verifications, Analytics, Scans, Sites, Users, Reports
- [ ] User authentication
- [ ] Real-time WebSocket updates
- [ ] Export functionality (CSV, PDF)
- [ ] Advanced filtering and search
- [ ] Notifications system
- [ ] Dark mode toggle

## Testing Checklist

Before deployment:
- [ ] API connection works
- [ ] Metrics display correctly
- [ ] Charts render properly
- [ ] Activity feed updates
- [ ] Site performance accurate
- [ ] Heatmap shows data
- [ ] Auto-refresh working
- [ ] Responsive on mobile
- [ ] Browser compatibility checked

## Notes

- This replaces the Flutter web version with a lighter, faster HTML implementation
- Designed to match the modern trading dashboard aesthetic with green/teal sidebar
- Features the official Geoacoustic Fingerprinting logo
- **All data is fetched in real-time from the FastAPI backend**
- **The API must be running at http://127.0.0.1:8000 for the dashboard to work**
- No backend changes required (uses existing API endpoints)

## Contact

For issues or questions, refer to the main project README at the root directory.
