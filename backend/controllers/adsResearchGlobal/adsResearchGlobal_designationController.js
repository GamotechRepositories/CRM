import Designation from "../../models/adsResearchGlobal/adsResearchGlobal_designation.js";

// Create a new designation
export const createDesignation = async (req, res) => {
  try {
    const { title, description } = req.body;
    const newDesignation = new Designation({ title, description });
    await newDesignation.save();
    res.status(201).json(newDesignation);
  } catch (error) {
    res.status(500).json({ message: "Error creating designation", error });
  }
};

// Get all designations
export const getDesignations = async (req, res) => {
  try {
    const designations = await Designation.find();
    res.status(200).json(designations);
  } catch (error) {
    res.status(500).json({ message: "Error fetching designations", error });
  }
};

// Get a single designation by ID
export const getDesignationById = async (req, res) => {
  try {
    const designation = await Designation.findById(req.params.id);  
    if (!designation) {
        return res.status(404).json({ message: "Designation not found" });
        }
    res.status(200).json(designation);
    }
    catch (error) {
    res.status(500).json({ message: "Error fetching designation", error });
    }
};

// Update a designation by ID
export const updateDesignation = async (req, res) => {
  try {
    const { title, description } = req.body;
    const updatedDesignation = await Designation.findByIdAndUpdate(
      req.params.id,
      { title, description },
      { new: true }
    );
    if (!updatedDesignation) {
        return res.status(404).json({ message: "Designation not found" });
        }
    res.status(200).json(updatedDesignation);
  } catch (error) {
    res.status(500).json({ message: "Error updating designation", error });
  }
};

// Delete a designation by ID
export const deleteDesignation = async (req, res) => {
  try {
    const deletedDesignation = await Designation.findByIdAndDelete(req.params.id);
    if (!deletedDesignation) {
        return res.status(404).json({ message: "Designation not found" });
        }
    res.status(200).json({ message: "Designation deleted successfully" });
  } catch (error) {
    res.status(500).json({ message: "Error deleting designation", error });
  }
};