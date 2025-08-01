const { body, validationResult } = require("express-validator");
const validator = require("validator");

const handleValidationError = async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: errors.array()[0].msg });
  }
  next();
};

const validateCredentials = [
  body("email")
    .custom((value) => {
      if (!validator.isEmail(value, { allow_utf8_local_part: true })) {
        throw new Error("Must be a valid email address");
      }
      return true;
    }),

  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be at least 6 characters long"),

  handleValidationError
];

module.exports = {
  validateCredentials,
};
