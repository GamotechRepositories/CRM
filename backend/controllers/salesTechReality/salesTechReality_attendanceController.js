import Attendance from '../../models/salesTechReality/salesTechReality_attendance.js';

const getStatus = (durationHours) => {
  if (durationHours >= 8) return 'Full Day';
  if (durationHours >= 4) return 'Half Day';
  return 'Half Day';
};

export const checkIn = async (req, res) => {
  try {
    const { employee, latitude, longitude, address } = req.body;
    const lat = typeof latitude === 'number' ? latitude : Number(latitude);
    const lon = typeof longitude === 'number' ? longitude : Number(longitude);
    if (employee == null) {
      return res.status(400).json({ message: 'Employee is required' });
    }
    if (Number.isNaN(lat) || Number.isNaN(lon)) {
      return res.status(400).json({ message: 'Check-in location is required. Enable device location and allow this site to use it.' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let attendance = await Attendance.findOne({
      employee,
      date: { $gte: today, $lt: new Date(today.getTime() + 24 * 60 * 60 * 1000) },
    });

    if (attendance?.checkIn) {
      return res.status(400).json({ message: 'Already checked in today' });
    }

    const checkInPayload = {
      checkIn: new Date(),
      status: 'In Progress',
      checkInLatitude: lat,
      checkInLongitude: lon,
    };
    if (typeof address === 'string' && address.trim()) {
      checkInPayload.checkInAddress = address.trim();
    }

    if (!attendance) {
      attendance = new Attendance({
        employee,
        date: today,
        ...checkInPayload,
      });
    } else {
      Object.assign(attendance, checkInPayload);
    }

    await attendance.save();
    const populated = await Attendance.findById(attendance._id).populate('employee');
    res.status(201).json({ message: 'Checked in successfully', attendance: populated });
  } catch (error) {
    res.status(500).json({ message: 'Error checking in', error });
  }
};

export const checkOut = async (req, res) => {
  try {
    const { employee, latitude, longitude, address } = req.body;
    const lat = latitude == null ? null : (typeof latitude === 'number' ? latitude : Number(latitude));
    const lon = longitude == null ? null : (typeof longitude === 'number' ? longitude : Number(longitude));
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let attendance = await Attendance.findOne({
      employee,
      date: { $gte: today, $lt: new Date(today.getTime() + 24 * 60 * 60 * 1000) },
    });

    // If no check-in today, apply auto checkout for previous day's open session (day ended)
    if (!attendance || !attendance.checkIn) {
      attendance = await Attendance.findOne({
        employee,
        checkIn: { $exists: true, $ne: null },
        checkOut: { $in: [null, undefined] },
      })
        .sort({ date: -1 })
        .limit(1)
        .exec();
      if (attendance) {
        // Set checkout to end of that day (day ended)
        const recordDate = new Date(attendance.date);
        recordDate.setHours(23, 59, 59, 999);
        attendance.checkOut = recordDate;
      }
    } else {
      attendance.checkOut = new Date();
      // Only capture location for a real (today) checkout initiated by user
      if (!Number.isNaN(lat) && !Number.isNaN(lon) && lat != null && lon != null) {
        attendance.checkOutLatitude = lat;
        attendance.checkOutLongitude = lon;
        if (typeof address === 'string' && address.trim()) {
          attendance.checkOutAddress = address.trim();
        }
      }
    }

    if (!attendance || !attendance.checkIn) {
      return res.status(400).json({ message: 'No check-in found for today' });
    }

    const durationMs = attendance.checkOut - attendance.checkIn;
    attendance.durationHours = durationMs / (1000 * 60 * 60);
    attendance.status = getStatus(attendance.durationHours);

    await attendance.save();
    const populated = await Attendance.findById(attendance._id).populate('employee');
    res.status(200).json({ message: 'Checked out successfully', attendance: populated });
  } catch (error) {
    res.status(500).json({ message: 'Error checking out', error });
  }
};

export const getTodayAttendance = async (req, res) => {
  try {
    const { employeeId, date } = req.query;
    let dayStart, dayEnd;
    if (date) {
      const parts = date.split('-').map(Number);
      if (parts.length !== 3 || parts.some(isNaN)) {
        return res.status(400).json({ message: 'Invalid date format. Use YYYY-MM-DD' });
      }
      dayStart = new Date(parts[0], parts[1] - 1, parts[2]);
      if (isNaN(dayStart.getTime())) {
        return res.status(400).json({ message: 'Invalid date' });
      }
      dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
    } else {
      dayStart = new Date();
      dayStart.setHours(0, 0, 0, 0);
      dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
    }

    const filter = { date: { $gte: dayStart, $lt: dayEnd } };
    if (employeeId) {
      filter.employee = employeeId;
    }

    const attendances = await Attendance.find(filter).populate('employee');

    res.status(200).json(attendances);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching attendance', error });
  }
};

export const getAttendanceByMonth = async (req, res) => {
  try {
    const { employeeId, month } = req.query;
    if (!month) {
      return res.status(400).json({ message: 'Month is required (YYYY-MM)' });
    }
    const parts = month.split('-').map(Number);
    if (parts.length !== 2 || parts.some(isNaN)) {
      return res.status(400).json({ message: 'Invalid month format. Use YYYY-MM' });
    }
    const monthStart = new Date(parts[0], parts[1] - 1, 1);
    const monthEnd = new Date(parts[0], parts[1], 1);

    const filter = { date: { $gte: monthStart, $lt: monthEnd } };
    if (employeeId) {
      filter.employee = employeeId;
    }

    const attendances = await Attendance.find(filter)
      .populate('employee')
      .sort({ date: 1 });

    res.status(200).json(attendances);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching attendance', error });
  }
};

export const getAttendanceByEmployee = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const attendances = await Attendance.find({ employee: employeeId })
      .populate('employee')
      .sort({ date: -1 });
    res.status(200).json(attendances);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching attendance', error });
  }
};
